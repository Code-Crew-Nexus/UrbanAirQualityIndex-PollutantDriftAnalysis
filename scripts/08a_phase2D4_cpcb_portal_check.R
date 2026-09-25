source("R/00_setup.R")
library(httr2)

# Attempt to check if CPCB CCR portal has an accessible API for historical data
# app.cpcbccr.com/ccr/
# app.cpcbccr.com/caaqms/

# Let's try a simple GET to see if it responds with an API or HTML
url <- "https://app.cpcbccr.com/ccr/"
req <- request(url) %>% req_error(is_error = function(resp) FALSE)
resp <- req_perform(req)

cat("CCR Status:", resp_status(resp), "\n")

url2 <- "https://app.cpcbccr.com/caaqms/api/data"
req2 <- request(url2) %>% req_error(is_error = function(resp) FALSE)
resp2 <- req_perform(req2)
cat("CAAQMS API Status:", resp_status(resp2), "\n")
