#' Get Kovats RIs from NIST database
#'
#' This is a wrapper function for the webchem function `nist_ri()`, which scrapes the NIST database for all RI data for all compounds in a given input file. It is not as efficient as it could be, because the nist_ri function needs to be called 3 times, once for each temperature program option. For some reason, it does not take a vector as an argument (using a vector of parameters doesn't throw an error, but only the first parameter is used). Will take some time to run, particularly if the number of unique compounds in the dataset is large.
#' @param Full_data A dataframe with at least one column of CAS numbers, with column label "CAS".
#' @param type The type of RI to be collected from NIST. Defaults to "kovats". Other options are "linear", "alkane", or "lee".
#' @param polarity The polarity of the GC column. Defaults to "non-polar". Other option is "polar".
#' @export
#' @examples
#' Get_kovats_RIs(Sample_data)

Get_kovats_RIs <- function(Full_data, type = "kovats", polarity = "non-polar"){
  Data <- Full_data[!duplicated(Full_data$CAS),]
  CAS_no <- as.character(Data[ ,"CAS"])
  RI_data_ramp <- webchem::nist_ri(cas = CAS_no,
                          type = type,
                          polarity = polarity,
                          temp_prog = "ramp")
  RI_data_isothermal <- webchem::nist_ri(cas = CAS_no,
                                type = type,
                                polarity = polarity,
                                temp_prog = "isothermal")
  RI_data_custom <- webchem::nist_ri(cas = CAS_no,
                            type = type,
                            polarity = polarity,
                            temp_prog = "custom")
  cols <- intersect(colnames(RI_data_ramp), colnames(RI_data_custom))
  RI_data <- rbind(RI_data_ramp[, cols],
                   RI_data_custom[,cols],
                   RI_data_isothermal[,cols])
}

#' Summarises the output of a NIST database search
#'
#' This function takes output of `nist_ri` or `Get_kovats_RIs` as an input and returns a matrix of CAS number, mean, standard deviation of the mean, and number of database samples.
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @export
#' @examples Summarise_RI_info(Sample_RI)

Summarise_RI_info <- function(RI_data) {
  as.matrix(aggregate(RI ~ CAS,
                      data = RI_data,
                      FUN = function(RI_data) {
                        c(mean = round(mean(RI_data)),
                          std = sd(RI_data),
                          n = length(RI_data))
                      } ))
  }

#' Adds database RI values to input dataframe
#'
#' This function takes a raw dataframe of GC output and RI database search results from that dataframe and combines them into a new dataframe no loss of information.
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @export
#' @examples Add_RI_data(Sample_data, Sample_RI)

Add_RI_data <- function(Full_data, RI_data) {
  RI_summaries <- Summarise_RI_info(RI_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  Combined$RI.mean <- as.numeric(paste(Combined$RI.mean))
  Combined$Difference <- abs(Combined$RI.mean-Combined$RI)
  Combined
}

#' Makes dataframe of good RI database matches
#'
#' This function takes a raw dataframe of GC output and RI database search results from that dataframe and combines them into a new dataframe of well-matched compounds with no loss of columns.
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @param Match_threshold The threshold at which a database RI value is considered matched with the calculated value. Defaults to 50.
#' @export
#' @examples Match_RI_data(Sample_data, Sample_RI)

Match_RI_data <- function(Full_data, RI_data, Match_threshold = 50) {
  RI_summaries <- Summarise_RI_info(RI_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  Combined$RI.mean <- as.numeric(paste(Combined$RI.mean))
  Combined$Difference <- abs(Combined$RI.mean-Combined$RI)
  Onlymatches <- Combined[!is.na(Combined$Difference),]
  Matched_RI <- Onlymatches[Onlymatches$Difference < Match_threshold, ]
}

#' Makes dataframe of poor RI database matches
#'
#' This function takes a raw dataframe of GC output and RI database search results from that dataframe and combines them into a new dataframe of poorly-matched compounds with no loss of columns..
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @param Match_threshold The threshold at which a database RI value is considered matched with the calculated value. Defaults to 50.
#' @export
#' @examples Poorly_matched_RI(Sample_data, Sample_RI)

Poorly_matched_RI <- function(Full_data, RI_data, Match_threshold = 50) {
  RI_summaries <- Summarise_RI_info(RI_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  Combined$RI.mean <- as.numeric(paste(Combined$RI.mean))
  Combined$Difference <- abs(Combined$RI.mean-Combined$RI)
  Onlymatches <- Combined[!is.na(Combined$Difference),]
  Matched_RI <- Onlymatches[Onlymatches$Difference > Match_threshold, ]
}

#' Makes dataframe of compounds with no database matches
#'
#' This function is a subset of `Matched_RI_data`, but returns a dataframe of only the compounds with no matches.
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @export
#' @examples No_matches(Sample_data, Sample_RI)

No_matches <- function(Full_data, RI_data){
  RI_summaries <- Summarise_RI_info(RI_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  RI_values <- Combined[is.na(Combined$RI.mean),]
}

#' All compounds with no or poor database matches
#'
#' This function is simply the inverse of `Match_RI_data`, and returns a dataframe of all compounds which are missing or are matched poorly.
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @param Threshold The threshold above which an RI match is considered poor. Defaults to 50.
#' @export
#' @examples Poor_or_no_matches(Sample_data, Sample_RI)

Poor_or_no_matches <- function(Full_data, RI_data, Threshold = 50){
  RI_summaries <- Summarise_RI_info(RI_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  Combined$RI.mean <- as.numeric(paste(Combined$RI.mean))
  Combined$Difference <- abs(Combined$RI.mean-Combined$RI)
  RI_values <- Combined[is.na(Combined$RI.mean)|Combined$Difference > Threshold,]
}

#' Only compounds with database matches
#'
#' This function is a subset of `Add_RI_data`, but returns a dataframe of only the compounds with database information available, regardless of whether or not the match is good.
#' @param Full_data A dataframe with at least one column of CAS numbers with column label "CAS", and one column of calculated RI values with column label "RI", one column of compound names called "Name",  and one column of sample identifiers called "File".
#' @param RI_data The output of `nist_ri` or `Get_kovats_RIs`
#' @export
#' @examples Only_matches(Sample_data, Sample_RI)

Only_matches <- function(Full_data, RI_data){
  RI_summaries <- Summarise_RI_info(Full_data)
  Combined <- merge(Full_data, RI_summaries, all.x = TRUE)
  RI_matches <- Combined[!is.na(Combined$RI.mean),]
}
