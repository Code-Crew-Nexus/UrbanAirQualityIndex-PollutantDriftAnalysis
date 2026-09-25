# Suggestions and Project Collaboration Policy

## Academic Project Context
This repository represents a college **Project Based Learning (PBL)** project for **Statistics for Machine Learning (SML)**. Active development, research analysis, modeling implementations, and codebase maintenance are conducted exclusively by the listed four project team members:

1. **Mangali Sai Krishna** (@Saikrishna-dev-oss)
2. **Md. Abdul Rayain** (@rayainwarrior-dev)
3. **RISHIT GHOSH** (@rajghosh06-dev)
4. **Yaram Karthik** (@karthik10-dev)

## External Contributions Policy
- **External Code Contributions & Pull Requests**: External code contributions and Pull Requests are **not accepted**. This repository is not structured as a general open-source contribution project.
- **External Issues & Bug-Fix Submissions**: External Issue tracking and bug-fix submissions are not the intended collaboration workflow for this academic project.
- **Academic Feedback & Suggestions**: Suggestions, research questions, academic literature references, methodological ideas, and constructive feedback are warmly welcomed and encouraged through **GitHub Discussions**.

---

## Internal Team Workflow
For the four project team members collaborating on the repository, the internal branching and integration workflow is defined as follows:

### Branch Strategy
Core branches and focused topic branches include:
- `main`: Canonical, reproducible, frozen milestone codebase.
- `feature/pca-kmeans`: Unsupervised pollution regime and dimensionality analysis.
- `feature/svm-classifier`: Support Vector Machine modeling extension.
- `feature/shiny-dashboard`: Interactive R Shiny analytical dashboard.
- `docs/final-report`: Academic report preparation and synthesis.
- `docs/presentation`: Slide deck and presentation asset preparation.
- `fix/<specific-team-fix>`: Targeted bug fixes and methodological repairs.

### Integration Workflow
Because external Pull Requests are disabled and this is a tightly coordinated four-member team:
1. Create a dedicated feature or task branch from `main`.
2. Implement and test changes locally.
3. Coordinate and review updates directly with teammates.
4. Perform local or authorized merge into `main` after verifying test passes and reproducibility.
5. Push the updated `main` branch.

Direct external modifications and uncoordinated direct pushes are prohibited.

---

## Internal Team Commit Conventions
To maintain a clean and reproducible commit history across project milestones, team members follow standard semantic commit prefixes:

- `feat:` (New features, models, or pipeline stages)
- `fix:` (Bug fixes in data processing or modeling scripts)
- `docs:` (Updates to markdown reports, summaries, or README)
- `test:` (Adding or fixing tests in `testthat`)
- `refactor:` (Code structural changes that do not affect model output)
- `chore:` (Routine repository maintenance, configuration updates)
- `data:` (Updates to frozen datasets or data mappings)

**Examples:**
- `feat: add PCA pollution regime analysis`
- `fix: correct station metadata filter`
- `docs: summarize supervised learning results`
- `test: add PCA preprocessing integrity checks`
