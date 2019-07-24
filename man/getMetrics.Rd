% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getMetrics.r
\name{getMetrics}
\alias{getMetrics}
\title{Get psd and signal to noise ratio for audio files}
\usage{
getMetrics(wav, freqLo = c(0.6, 4.4), freqHi = c(1.2, 5.6),
  fn = c("meanspec", "spec"), parallel = F)
}
\arguments{
\item{wav}{A vector of wav filenames (including directories)}

\item{freqLo}{a vector of Lower frequency cut offs - defaults to 2 bands (0.6-1.2 kHz and 4.4-5.6 kHz)}

\item{freqHi}{a vector of Higher frequency cut off - defaults to 2 bands: (0.6-1.2 kHz and 4.4-5.6 kHz)}

\item{fn}{a character vector, which seewave function to use: spec or meanspec (see details)}

\item{parallel}{Logical. Whether to use multicore processing with the parallel package (must be loaded)}
}
\value{
a numeric matrix with columns \code{psd} and \code{s2n} for each wav file in \code{wav},
filenames are conserved in the rownames
}
\description{
This function does not generally need to be called directly. It is the workhorse function that
reads wav files, extracts psd and signal to noise for specified frequency bands using seewave
functions spec() or meanspec(). This is called by getThreshold() and classifyRain() which will generally
be called directly.
}
\examples{
see \\code{\\link{getThreshold}}, \\code{\\link{classifyRain}}

}