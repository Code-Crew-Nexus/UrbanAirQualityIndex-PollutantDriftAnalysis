source("R/00_setup.R")
source("R/01_utils.R")

log_info("Starting Stage A: Metadata Shortlisting")

cat_path <- "data/metadata/station_catalog.csv"
if (!file.exists(cat_path)) {
  stop("station_catalog.csv not found")
}

catalog <- read.csv(cat_path, stringsAsFactors = FALSE)

# Derive recently_active (e.g., active within the last 180 days)
catalog$days_since_last_observation <- as.numeric(difftime(Sys.time(), as.POSIXct(catalog$last_observation_date, format="%Y-%m-%dT%H:%M:%S", tz="UTC"), units="days"))
catalog$activity_status <- ifelse(is.na(catalog$days_since_last_observation), "unknown",
                                  ifelse(catalog$days_since_last_observation <= 180, "active_recent", "inactive_or_stale"))

# Shortlist Hyderabad
hyd <- subset(catalog, city == "Hyderabad")

# Improve geographic scope
hyd$geographic_scope <- "uncertain"
for(i in seq_len(nrow(hyd))) {
   n <- tolower(paste(hyd$station_name[i], hyd$locality[i]))
   if (grepl("pashamylaram|patancheru|kandi|ramachandrapuram", n)) {
      hyd$geographic_scope[i] <- "peripheral_candidate"
   } else if (grepl("sanathnagar|zoo park|somajiguda|abids|banjara hills|jubilee hills|hcu|nacharam|uppal|malakpet|charminar", n)) {
      hyd$geographic_scope[i] <- "strict_or_core_hyderabad_candidate"
   } else {
      hyd$geographic_scope[i] <- "metro_candidate"
   }
}

# Duplicate Review
hyd$norm_name <- tolower(gsub("[^a-zA-Z]", "", hyd$station_name))
# For those with "icrisat" or "sanathnagar" etc
hyd$norm_name <- ifelse(grepl("icrisat", hyd$norm_name), "icrisatpatancheru", hyd$norm_name)
hyd$norm_name <- ifelse(grepl("sanath", hyd$norm_name), "sanathnagar", hyd$norm_name)

hyd$duplicate_group <- NA
hyd$record_status <- "inactive"

groups <- unique(hyd$norm_name)
for (g in groups) {
   idx <- which(hyd$norm_name == g)
   hyd$duplicate_group[idx] <- g
   
   if (length(idx) == 1) {
      if (hyd$activity_status[idx] == "active_recent") {
         hyd$record_status[idx] <- "unique_current"
      }
   } else {
      sub_hyd <- hyd[idx, ]
      active_idx <- which(sub_hyd$activity_status == "active_recent")
      if (length(active_idx) > 0) {
         # Sort active ones by latest observation
         ord <- order(sub_hyd$days_since_last_observation[active_idx])
         best_i <- active_idx[ord[1]]
         hyd$record_status[idx[best_i]] <- "preferred_current_location"
         
         # Others are legacy or alternate
         other_i <- setdiff(seq_len(nrow(sub_hyd)), best_i)
         for (o in other_i) {
            if (sub_hyd$activity_status[o] == "active_recent") {
               hyd$record_status[idx[o]] <- "alternate_location_record"
            } else {
               hyd$record_status[idx[o]] <- "legacy_location_record"
            }
         }
      } else {
         hyd$record_status[idx] <- "legacy_location_record"
      }
   }
}
hyd$norm_name <- NULL

write.csv(hyd, "data/metadata/hyderabad_station_review.csv", row.names = FALSE)
log_info("Created data/metadata/hyderabad_station_review.csv")

# India Shortlist (1-3 candidates per city)
india_shortlist <- data.frame()

for (c in unique(catalog$city)) {
  c_stat <- subset(catalog, city == c)
  
  # Prefer recently active, high core sensor count
  c_stat <- c_stat[order(c_stat$activity_status == "active_recent", c_stat$core_pollutants_available_count, decreasing = TRUE), ]
  
  # Pick top 3
  top <- head(c_stat, 3)
  top$shortlist_status <- "Recommended for coverage audit"
  
  india_shortlist <- rbind(india_shortlist, top)
}

write.csv(india_shortlist, "data/metadata/india_station_shortlist.csv", row.names = FALSE)
log_info("Created data/metadata/india_station_shortlist.csv")
