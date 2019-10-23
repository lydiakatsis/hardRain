
#' @export

#' @title Get PSD and Signal-to-Noise Ratio for audio files
#' @description This function does not generally need to be called directly. It is the workhorse function that
#' reads wav files, extracts Power Spectrum Density (PSD) and Signal-to-Noise (s2n) for specified frequency bands
#' using seewave function \code{spectro()}. This function is called by getThreshold() and classifyRain() which will
#' generally be used directly.
#'
#' @param wav A vector of wav filenames (including directories) or an object of class wav from the tuner package (see parallel, below)
#' @param freqLo A numeric vector of Lower frequency cut offs for each band.
#' @param freqHi A numeric vector of Higher frequency cut offs for each band.
#' @param t.step NULL or a numeric vector giving time in seconds in which to divide
#' longer files. If NULL, it is assumed that all files analysed are suitably short (e.g. 15 s each)
#' and do not need to be subdivided (see details)
#' @param parallel Logical. Whether to use multicore processing with the parallel package (Windows only)
#' (must be loaded). If wav is a single wav object it makes no sense to use parallel here (rather use hardRain functions within a larger parallelised loop).
#' @return A numeric matrix with columns \code{psd} and \code{s2n} for each wav file in \code{wav},
#' filenames are conserved in the rownames
#' @examples See examples in getThreshold() and \code{\link{classifyRain}}


getMetrics <- function(wav, freqLo = c(0.6, 4.4), freqHi = c(1.2,5.6), t.step = NULL, parallel = F){

  # These are in dependencies, so don't need to be here for final package functions
  # library(seewave)
  # library(tuneR)

  ## TO DO... not designed for single wav objects... so need to streamline code for this... ie at moment
  ## lots of apply functions for single wav object, and progress bar, etc etc..



  if(length(wav) == 0 | is.null(wav)) stop("wav filenames do not exist")
  if(!class(wav) %in% c("character", "Wave")) stop("wav must be either a character vector of filenames or a single wav object from tuneR package")

  if(!is.null(t.step)){

    if(!is.numeric(t.step)) stop("t.step must be numeric - see details") else {

      if(t.step > 60) warning("Long time divisions may not give sensible results, consider 20 s or less.")
    }

  }


  # check for presence of fftw package and use if present
  if(requireNamespace("fftw", quietly = TRUE)) {
    fftw <- T
  } else {
    fftw <- F
  }

  # check that freqLo and freqHi are same length
  if(length(freqLo) != length(freqHi)) stop("freqLo and freqHi must be the same length")

  # check freqLo and freqHi are within sensible limits
  if(!all(freqLo > 0, freqHi < 10.0)) stop("Check values of freqLo and freqHi are >0, <10, respectively")

  # check that freqHi > freqLo
  if(!all(freqHi > freqLo)) stop("freqHi must be higher than freqLo pairwise")

  # catch read wav errors, with try and record them here: Only when wav is filenames
  if(class(wav) == "character") tryError <- vector(mode = "logical", length = length(wav))

  if(parallel){

    # library(parallel) # in base R.. so ok just to ::

    noCores <- parallel::detectCores() - 1
    cl <- parallel::makeCluster(noCores)

    parallel::clusterExport(cl, c("wav", "t.step", "fftw", "freqLo", "freqHi"), envir = environment())
    parallel::clusterEvalQ(cl, {
      library(seewave)
      library(tuneR)
    }
    )
    # appFn <- parallel::parLapply

    ## do a burn in? not sure this helps, but second time around often seems quicker... is there some caching going
    ## on somewhere?

    # if(burnIn){
    #   print("Doing burn in...")
    #   mfs.tmp <- parallel::parLapply(cl, wav[1], function(x) {
    #
    #     b <- tuneR::readWave(x, header = T) # read in audiofile
    #     if(b$samples/b$sample.rate > 15) to <- 10 else to <- floor(b$samples/b$sample.rate)
    #     b <- tuneR::readWave(x, from = 1, to = to, units = "seconds") # read in audiofile
    #     f <- as.numeric(b@samp.rate)
    #     # get freq spectrum
    #     fs <- seewave::spectro(b, wl = 512, wn="rectangle", fftw=fftw, plot=F, dB = NULL) #
    #     # str(fs)
    #
    #   })
    #   rm(mfs.tmp)
    # }

    # is it quicker to export all wav objects

    mfs.lst <- parallel::parLapply(cl, wav, function(x) {

      #if(!parallel) setTxtProgressBar(pb, which(x == wav))

      if(class(wav) == "Wave"){b <- wav} else {

        # read in audiofile
        b <- tuneR::readWave(x)

        ## FINISH THIS...
        ## what happens if a mfs.lst element is NA further down.... find out, before adding this...

        # b <- try(tuneR::readWave(x), silent = T)
        #
        # tryErr <- inherits(b, "try-error")
        # tryError[which(wav == x)] <- tryErr

      }

      ## hacky way....
      # if(class(wav) == "Wave" & tryErr) NA else {

      f <- as.numeric(b@samp.rate)

      # get wl from t.step (a few ms will probably be left unprocessed at end of each file with step)
      if(!is.null(t.step)) wl <- t.step*f else wl <- length(b)
      wl <- wl - wl%%2 # make sure it's even

      # get freq spectrum
      fs <- seewave::spectro(b, wl = wl, wn="rectangle", fftw=fftw, plot=F, dB = NULL) # wl = 512 default, ...
      # str(fs)
      # with dB = NULL, then this gives a ^2 already, even if dBref is NULL
      # 'dB' argument computes 20*log10(x) where x is the FFT, which is equivalent to 10*log10(x^2)
      # why does ... work wiht parallel, when dB isn't exported?? because the value is given.. whereas wav is not.
      # p 235 of Sueur book for amplitude normalisation.

      # take psd scores for each rain frequency window in khz
      mapply(function(lo,hi) fs$amp[fs$freq > lo & fs$freq < hi, ,drop = F],
             freqLo, freqHi, SIMPLIFY = F)
      # str(tmp2)

      #} # end of else if not a try error

    })

    parallel::stopCluster(cl)


  } else {

    # appFn <- lapply
    pb <- txtProgressBar(min = 0, max = length(wav), style = 3) # length of all wavs?

    mfs.lst <- lapply(wav, function(x) {

      setTxtProgressBar(pb, which(x == wav))

      if(class(wav) == "Wave"){b <- wav} else {

        # read in audiofile
        b <- tuneR::readWave(x)

        # FINISH THIS....
        # b <- try(tuneR::readWave(x), silent = T)
        #
        # tryErr <- inherits(b, "try-error")
        # tryError[which(wav == x)] <- tryErr

      }



      f <- as.numeric(b@samp.rate)

      # get wl from t.step (a few ms will probably be left unprocessed at end of each file with step)
      if(!is.null(t.step)) wl <- t.step*f else wl <- length(b)
      wl <- wl - wl%%2 # make sure it's even

      # get freq spectrum
      fs <- seewave::spectro(b, wl = wl, wn="rectangle", fftw=fftw, plot=F, dB = NULL) #, ...  wl = 512 default
      # str(fs)
      # with dB = NULL, then this gives a ^2 already, even if dBref is NULL
      # 'dB' argument computes 20*log10(x) where x is the FFT, which is equivalent to 10*log10(x^2)

      # take psd scores for each rain frequency window in khz
      mapply(function(lo,hi) fs$amp[fs$freq > lo & fs$freq < hi, ,drop = F],
           freqLo, freqHi, SIMPLIFY = F)
      #str(psd.freq)
  })

    close(pb)
  }


  if(class(wav)== "character") {
    dodgy.files <- wav[tryError.ind]
    wav <- wav[!tryError.ind]
    warning(paste(sum(tryError), "wav files failed to read - possibly corrupt. Check these files:\n",
                paste(dodgy.files, collapse = "\n")), call. = T)
  }


  # str(res2)
  # head(res2)
  # str(mfs.lst)
  # x <- mfs.lst[[1]]
  # It's hard, hard, rain a gonna fall...

  # Get metrics here
  res <- lapply(mfs.lst, function(x) {

    psd <- sapply(x, colMeans) # psd of filtered frequency window
    s2n <- sapply(x, function(y) apply(y, 2, function(z) mean(z)/sd(z))) # sig2noise ratio
    list(psd=matrix(psd, ncol = length(freqLo)), s2n=matrix(s2n, ncol = length(freqLo)))
    # above, make format consistent as matrix..  if slow, then use if(is.null(t.step))

  })

  #head(res)
  # return(res)

  # reformat list - store as numeric matrix with rownames attributes as filenames
  tmp <- lapply(1:2, function(x) do.call(rbind, sapply(res, function(y) y[x])))
  res2 <- do.call(cbind, tmp)
  # # head(res2)
  cNames <- apply(expand.grid("band", seq_along(freqLo), c("psd", "s2n"), KEEP.OUT.ATTRS = F),
                  1, paste0, collapse = ".")
  name.exp <- sapply(res, function(x) sapply(x, nrow)[1])
  dimnames(res2) <- list(mapply(function(x,y) rep(x, each= y), basename(wav), name.exp), cNames)

  if(!is.null(t.step)) {

    duration <- lapply(mapply(function(x,y) rep(x, y), t.step, name.exp, SIMPLIFY = F), cumsum)
    attributes(res2) <-  c(attributes(res2), t.step = t.step, duration = list(unlist(duration)))
  }
  rm(tmp, cNames)

  return(res2)


}
