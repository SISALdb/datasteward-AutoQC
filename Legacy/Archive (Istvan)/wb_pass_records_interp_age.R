# quality check workbooks present in 'records' directory (google drive). If QC_log shows only warnings due to 'interp_age occurred more than once', the record passes QC.
# 1. wb_check.py script and outputs a QC_log txt file with warnings. If no warnings are given, the workbook is renamed with the prefix 'QC_passed_'
# 2. agemodel hiatus plots are then generated for all workbooks
# 3. The workbook is then listed in the QC_passed_list or QC_failed_list txt files accordingly

rm(list=ls())

path <- "~/Documents/WSL/sisal/scripts/sisal/wb_QC/"
setwd(path)

source("plot_agemodels_hiatus.R")
has.null <- function(filename, tibble = T) {
  sheets <- readxl::excel_sheets(filename)
  x <- lapply(sheets, function(X) readxl::read_excel(filename, sheet = X, skip = 1, .name_repair = "minimal"))
  if(!tibble) x <- lapply(x, as.data.frame)
  names(x) <- sheets
  x.null <- grepl("NULL", x)
  if (any(x.null)) {
    writeLines(paste0("NULL values in ", paste0(names(x[x.null]), collapse = ", ")))
    return(T)
  } else {
    return(F)
  }
}

# list all workbooks
filenames <- list.files(path = paste0(path,"records"), full.names = F, pattern = glob2rx("*SISAL_*v14*.xlsx"), recursive = T,  no.. = T) 
filenames <- filenames[!grepl("~", filenames, fixed = T)]
records   <- strsplit(filenames, "/", fixed = T)

cat("", file = paste0("records/QC_passed_list.txt"))
cat("", file = paste0("records/QC_failed_list.txt"))


if (length(records) != 0) {
  for (r in 1:length(records)) {
    if (any(records[[r]] == "checked")) {
      k = 1
    } else {
      k = 0
    }
    typ <- records[[r]][1]
    rec <- records[[r]][k+2]
    xls <- records[[r]][k+3]
    
    pth <- paste0("records/", dirname(filenames[r]))

    writeLines(paste0("\nr = ", r, " ", rec, " (", typ, ")"))
    if (has.null(paste0("records/", filenames[r]))) {
      writeLines(paste0("Skipping ", xls))
      next
    }
    
    ts <- format(Sys.time(), "%Y-%m-%d-%H%M")
    # if (!file.exists(chk)) {
    system(paste0("rm ", pth, "/QC_log_*.txt"), wait = T)
    system(paste0("/opt/anaconda3/bin/python wb_check.py ", paste0(pth, "/ ", xls) ," > ", pth, "/QC_log_", rec, "_", ts, ".txt"), wait = T)
    # }
    # try(plot_agemodels_hiatus(pth, paste0("QC_passed_", xls)), silent = T)
    try(plot_agemodels_hiatus(pth, xls), silent = T)
    
    # define acceptable warning text
    log <- read.delim(paste0(path, pth, '/QC_log_', rec, "_", ts, '.txt'), sep = "\n", header = F)
    wr.interp_age <- grepl("interp_age occured more than once", log$V1)
    
    # calc number of warnings
    wr.n <- try(as.numeric(strsplit(log$V1[grep("warning/s detected", log$V1)], " ", fixed = T)[[1]][1]), silent = T)
    if ("try-error" %in% class(wr.n)) {
      writeLines("There QC log is not complete. Skipping record")
      wr.n = 999
    }
    
    # list files as passed or failed
    corr_pass <- strsplit(xls, "QC_passed_", fixed = T)
    corr_fail <- strsplit(xls, "QC_failed_", fixed = T)
    if (lengths(corr_pass) > 1) {
      xls.orig <- corr_pass[[1]][2]
    } else if (lengths(corr_fail) > 1) {
      xls.orig <- corr_fail[[1]][2]
    } else {
      xls.orig <- xls
    }
    
    if (wr.n == 0) {
      writeLines(paste0(rec, " passed"))
      cat(paste0(typ, "/", rec, "   passed  ", ts, "\n"), file = paste0("records/QC_passed_list.txt"), append = T)
      file.rename(from = paste0(pth, "/", xls), to = paste0(pth, "/QC_passed_", xls.orig))
    } else if ((sum(wr.interp_age) == wr.n)) {
      writeLines(paste0(rec, " passed (see interp_age in log file)"))
      cat(paste0(typ, "/", rec, "   passed (see interp_age in log file)  ", ts, "\n"), file = paste0("records/QC_passed_list.txt"), append = T)
      file.rename(from = paste0(pth, "/", xls), to = paste0(pth, "/QC_passed_", xls.orig))
    } else {
      wrngs <- unlist(tail(read.delim(paste0(path, pth, '/QC_log_', rec, "_", ts, '.txt'), sep = "\n", header = F), 1))
      writeLines(wrngs)
      cat(paste0(pth, "   ", wrngs, "   ", ts, "\n"), file = paste0("records/QC_failed_list.txt"), append = T)
      file.rename(from = paste0(pth, "/", xls), to = paste0(pth, "/QC_failed_", xls.orig))
    }
  }
} else {
  writeLines("No new records to quality check!")
}
