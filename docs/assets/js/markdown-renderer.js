/**
 * markdown-renderer.js
 * Project: UrbanAirQualityIndex-PollutantDriftAnalysis
 * 
 * High-performance, secure, offline-first Markdown and KaTeX mathematical
 * rendering engine. Adheres to Documentation Single-Source Principle.
 */

(function (window) {
  "use strict";

  const MarkdownRenderer = {
    /**
     * Initializes the Markdown parser and extensions.
     */
    init: function () {
      if (typeof marked === "undefined") {
        console.error("Marked.js is not loaded.");
        return;
      }

      // Configure marked defaults
      marked.setOptions({
        gfm: true,
        breaks: false,
        pedantic: false
      });
    },

    /**
     * Pre-processes Markdown to safely isolate math equations and protect them
     * from Markdown text transforms (e.g. subscripts _ turning into <em>).
     */
    protectAndRenderMath: function (rawMarkdown) {
      if (typeof katex === "undefined") {
        console.warn("KaTeX is not loaded; returning unrendered Markdown.");
        return { markdown: rawMarkdown, mathStore: [] };
      }

      const mathStore = [];
      let tokenIndex = 0;

      // 1. Protect fenced code blocks and inline code
      const codeBlocks = [];
      let sanitized = rawMarkdown.replace(/(```[\s\S]*?```|`[^`\n]+`)/g, function (match) {
        const placeholder = `%%%CODE_BLOCK_${codeBlocks.length}%%%`;
        codeBlocks.push(match);
        return placeholder;
      });

      // 2. Extract and render display math: $$ ... $$
      sanitized = sanitized.replace(/\$\$([\s\S]*?)\$\$/g, function (match, tex) {
        const cleanTex = tex.trim();
        let rendered = "";
        try {
          rendered = katex.renderToString(cleanTex, {
            displayMode: true,
            throwOnError: false,
            output: "htmlAndMathml"
          });
        } catch (err) {
          rendered = `<div class="katex-error" title="${err.message}">$$ ${cleanTex} $$</div>`;
        }

        const placeholder = `%%%MATH_TOKEN_${tokenIndex++}%%%`;
        mathStore.push({
          placeholder: placeholder,
          html: `<div class="katex-display-wrapper">${rendered}</div>`
        });
        return `\n\n${placeholder}\n\n`;
      });

      // 3. Extract and render inline math: $ ... $
      // Must not match escaped \$ or empty $$
      sanitized = sanitized.replace(/(^|[^\\])\$([^\$\n\r]+?)\$/g, function (match, prefix, tex) {
        const cleanTex = tex.trim();
        let rendered = "";
        try {
          rendered = katex.renderToString(cleanTex, {
            displayMode: false,
            throwOnError: false,
            output: "htmlAndMathml"
          });
        } catch (err) {
          rendered = `<span class="katex-error" title="${err.message}">$${cleanTex}$</span>`;
        }

        const placeholder = `%%%MATH_TOKEN_${tokenIndex++}%%%`;
        mathStore.push({
          placeholder: placeholder,
          html: rendered
        });
        return `${prefix}${placeholder}`;
      });

      // 4. Restore code blocks
      sanitized = sanitized.replace(/%%%CODE_BLOCK_(\d+)%%%/g, function (match, idx) {
        return codeBlocks[parseInt(idx, 10)];
      });

      return { markdown: sanitized, mathStore: mathStore };
    },

    /**
     * Resolves repository-relative links and media paths for documents
     * located in subdirectories (e.g., guide/ or reports/) when viewed in docs/ root pages.
     */
    rewriteRelativeUrls: function (html, docPath) {
      const docDir = docPath.indexOf("/") !== -1 ? docPath.substring(0, docPath.lastIndexOf("/") + 1) : "";

      // Create a temporary container to safely manipulate DOM elements
      const container = document.createElement("div");
      container.innerHTML = html;

      // Rewrite Images
      const images = container.querySelectorAll("img");
      images.forEach(function (img) {
        let src = img.getAttribute("src");
        if (!src) return;

        // Security check: reject local file:/// URLs
        if (src.indexOf("file:") === 0 || src.indexOf("C:") === 0 || src.indexOf("D:") === 0) {
          console.warn("Blocked absolute local path in image:", src);
          img.setAttribute("src", "");
          img.setAttribute("alt", "Security notice: local file URLs are disallowed.");
          return;
        }

        // Relative path resolution
        if (!src.match(/^https?:\/\//) && !src.startsWith("/")) {
          if (docDir) {
            // E.g., doc in 'guide/' referencing '../figures/img.png' -> 'figures/img.png'
            if (src.startsWith("../")) {
              src = src.replace(/^\.\.\//, "");
            } else if (!src.startsWith(docDir)) {
              src = docDir + src;
            }
          }
          img.setAttribute("src", src);
        }
      });

      // Rewrite Links
      const links = container.querySelectorAll("a");
      links.forEach(function (a) {
        let href = a.getAttribute("href");
        if (!href) return;

        // Security check: reject local file:/// URLs
        if (href.indexOf("file:") === 0 || href.indexOf("C:") === 0 || href.indexOf("D:") === 0) {
          console.warn("Blocked absolute local path in link:", href);
          a.setAttribute("href", "#");
          a.innerText += " (link disabled: local path)";
          return;
        }

        // Handle relative links
        if (!href.match(/^https?:\/\//) && !href.startsWith("#") && !href.startsWith("mailto:")) {
          // Normalize path relative to repository root (docs/<docDir>)
          const currentDocDir = docDir ? "docs/" + docDir.replace(/\/$/, "") : "docs";
          const normalizedRepoPath = MarkdownRenderer.normalizeRepoPath(currentDocDir, href);

          // If the path resolves outside docs/, convert to canonical GitHub repository URL
          if (!normalizedRepoPath.startsWith("docs/") && normalizedRepoPath !== "docs") {
            const githubUrl = "https://github.com/Code-Crew-Nexus/UrbanAirQualityIndex-PollutantDriftAnalysis/blob/main/" + normalizedRepoPath;
            a.setAttribute("href", githubUrl);
            a.setAttribute("target", "_blank");
            a.setAttribute("rel", "noopener noreferrer");
            a.classList.add("repo-outside-link");
            return;
          }

          // Path is inside docs/
          const pathInsideDocs = normalizedRepoPath.replace(/^docs\//, "");

          // Intercept markdown document links within the documentation viewer
          if (pathInsideDocs.endsWith(".md")) {
            a.setAttribute("data-doc-source", pathInsideDocs);
            a.setAttribute("href", "#doc=" + encodeURIComponent(pathInsideDocs));
            a.classList.add("doc-internal-link");
          } else {
            a.setAttribute("href", pathInsideDocs);
          }
        }
      });

      return container.innerHTML;
    },

    /**
     * Resolves a relative path against a base directory relative to the repository root.
     */
    normalizeRepoPath: function (baseDir, relativePath) {
      const cleanRelative = relativePath.split("#")[0].split("?")[0];
      const stack = baseDir ? baseDir.split("/").filter(Boolean) : [];
      const parts = cleanRelative.split("/");

      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (part === "." || part === "") continue;
        if (part === "..") {
          if (stack.length > 0) {
            stack.pop();
          }
        } else {
          stack.push(part);
        }
      }
      return stack.join("/");
    },

    /**
     * Enhances rendered HTML with accessible Copy buttons for code blocks.
     */
    enhanceCodeBlocks: function (container) {
      const codeBlocks = container.querySelectorAll("pre");
      codeBlocks.forEach(function (pre) {
        // Prevent duplicate copy buttons
        if (pre.querySelector(".code-copy-btn")) return;

        pre.classList.add("code-block-enhanced");

        const copyBtn = document.createElement("button");
        copyBtn.className = "code-copy-btn";
        copyBtn.type = "button";
        copyBtn.setAttribute("aria-label", "Copy code to clipboard");
        copyBtn.innerText = "Copy";

        copyBtn.addEventListener("click", function () {
          const codeEl = pre.querySelector("code") || pre;
          const textToCopy = codeEl.innerText.trim();

          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(textToCopy).then(function () {
              copyBtn.innerText = "Copied!";
              copyBtn.classList.add("copied");
              setTimeout(function () {
                copyBtn.innerText = "Copy";
                copyBtn.classList.remove("copied");
              }, 2000);
            }).catch(function () {
              fallbackCopy(textToCopy, copyBtn);
            });
          } else {
            fallbackCopy(textToCopy, copyBtn);
          }
        });

        pre.appendChild(copyBtn);
      });

      function fallbackCopy(text, btn) {
        const textarea = document.createElement("textarea");
        textarea.value = text;
        textarea.style.position = "fixed";
        textarea.style.opacity = "0";
        document.body.appendChild(textarea);
        textarea.select();
        try {
          document.execCommand("copy");
          btn.innerText = "Copied!";
          setTimeout(function () { btn.innerText = "Copy"; }, 2000);
        } catch (e) {
          btn.innerText = "Failed";
        }
        document.body.removeChild(textarea);
      }
    },

    /**
     * Fetches and renders a Markdown document into a target DOM container.
     */
    loadDocument: function (docPath, targetElement, callback) {
      if (!targetElement) {
        console.error("Target container element not found for doc:", docPath);
        return;
      }

      // Security validation: Only load relative project files
      if (docPath.indexOf("://") !== -1 || docPath.startsWith("//")) {
        targetElement.innerHTML = `
          <div class="render-error alert alert-danger">
            <h4>Security Violation</h4>
            <p>Remote document loading is prohibited. Only repository-tracked documents may be rendered.</p>
          </div>`;
        return;
      }

      // Display loading state
      targetElement.innerHTML = `
        <div class="doc-loading-spinner" role="status">
          <div class="spinner"></div>
          <p>Loading document: <code>${docPath}</code>...</p>
        </div>`;

      fetch(docPath)
        .then(function (response) {
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
          }
          return response.text();
        })
        .then(function (rawMarkdown) {
          // 1. Isolate and render math
          const mathPrep = MarkdownRenderer.protectAndRenderMath(rawMarkdown);

          // 2. Parse Markdown
          let html = marked.parse(mathPrep.markdown);

          // 3. Restore rendered KaTeX math tokens
          if (mathPrep.mathStore && mathPrep.mathStore.length > 0) {
            mathPrep.mathStore.forEach(function (item) {
              html = html.replace(item.placeholder, item.html);
            });
          }

          // 4. Rewrite URLs
          html = MarkdownRenderer.rewriteRelativeUrls(html, docPath);

          // 5. Update target container
          targetElement.innerHTML = html;

          // 6. Enhance code blocks
          MarkdownRenderer.enhanceCodeBlocks(targetElement);

          // 7. Scroll to top or anchor
          window.scrollTo({ top: 0, behavior: "smooth" });

          if (typeof callback === "function") {
            callback(null, { docPath: docPath });
          }
        })
        .catch(function (error) {
          console.error("Error loading Markdown document:", error);
          targetElement.innerHTML = `
            <div class="render-error alert alert-warning">
              <h3>Unable to Load Document</h3>
              <p>Could not retrieve <code>${docPath}</code>.</p>
              <p class="error-detail"><em>${error.message}</em></p>
              <p class="error-hint">If viewing locally, verify that you are running via a local HTTP server (<code>py -m http.server 8000 --directory docs</code>) and not opening files directly over <code>file://</code>.</p>
            </div>`;
          if (typeof callback === "function") {
            callback(error);
          }
        });
    }
  };

  // Export to window
  window.MarkdownRenderer = MarkdownRenderer;

  // Auto-init on script load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", MarkdownRenderer.init);
  } else {
    MarkdownRenderer.init();
  }
})(typeof window !== "undefined" ? window : this);
