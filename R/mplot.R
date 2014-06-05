
#' Generic plotting
#' 
#' Generic function plotting for R objects.  Currently plots exist for 
#' \code{data.frame}s, \code{lm}s, (including \code{glm}s).
#' 
#' @rdname mplot
#' @param object an R object from which a plot will be constructed.
#' @export

mplot <- function(object, ...) {
  UseMethod("mplot")  
}

#' @rdname mplot
#' @param which a numeric vector used to select from 7 potential plots
#' @param ask if TRUE, each plot will be displayed separately after the user 
#' responds to a prompt.
#' @param multiplot if TRUE and \code{ask == FALSE}, all plots will be 
#' displayed together.
#' @param ... additional arguments.  If \code{object} is an \code{lm}, these
#' are passed to \code{\link{grid.arrange}},
#' \code{nrow} and \code{ncol} can be used to control the number of rows
#' and columns used.
#' @export
#' @examples
#' mplot( lm( width ~ length + sex, data=KidsFeet), w=1:6, nrow=3 )
#' mplot( lm( width ~ length + sex, data=KidsFeet), w=1:6, nrow=3, 
#' system="ggplot2" )
mplot.lm <- function(object, which=c(1:3, 5), 
                     system=c("lattice","ggplot2","base"),
                     ask=FALSE, 
                     multiplot=TRUE,
                     ...){
  
  system <- match.arg(system)
  
  if (system == "base") {
    return(plot( object, which=intersect(which, 1:6)))
  }
  
  fdata <- ggplot2::fortify(object)
  fdata <- cbind(fdata, row=1:nrow(fdata))
  
  if (!inherits(object, "lm")) 
    stop("use only with \"lm\" objects")
  if (!is.numeric(which) || any(which < 1) || any(which > 7)) 
    stop("'which' must be in 1:7")
  isGlm <- inherits(object, "glm")
  show <- rep(FALSE, 7)
  show[which] <- TRUE
  
  ylab23 <- if (isGlm) 
    "Std. deviance resid."
  else "Standardized residuals"
  
  
  # residuals vs fitted
  g1 <- ggplot(fdata, aes(.fitted, .resid)) +
    geom_point()  +
    geom_smooth(se=FALSE) +
    geom_hline(linetype=2, size=.2) +
    scale_x_continuous("Fitted Values") +
    scale_y_continuous("Residual") +
    labs(title="Residuals vs Fitted")
  
  l1 <- xyplot( .resid ~ .fitted, data=fdata,
                type=c("p","smooth"),
                panel=function(x,y,...) {
                  panel.abline(h=0, linetype=2, lwd=.5) 
                  panel.xyplot(x,y,...)
                },
                main="Residuals vs Fitted",
                xlab="Fitted Value",
                ylab="Residual"
  )
  
  # normal qq
  a <- quantile(fdata$.stdresid, c(0.25, 0.75))
  b <- qnorm(c(0.25, 0.75))
  slope <- diff(a)/diff(b)
  int <- a[1] - slope * b[1]
  g2 <- ggplot(fdata, aes(sample=.stdresid)) +
    stat_qq() +
    geom_abline(slope=slope, intercept=int) +
    scale_x_continuous("Theoretical Quantiles") +
    scale_y_continuous("Standardized Residuals") +
    labs(title="Normal Q-Q")
  
  l2 <- qqmath( ~ .stdresid, data=fdata, 
                panel=function(x,...) {
                  panel.abline(a=int, b=slope)
                  panel.qqmath(x,...)
                },
                main="Normal Q-Q",
                xlab="Theoretical Quantiles",
                ylab=ylab23
  )
  
  # scale-location
  
  g3 <- ggplot(fdata, aes(.fitted, sqrt(abs(.stdresid)))) +
    geom_point() +
    geom_smooth(se=FALSE) +
    scale_x_continuous("Fitted Values") +
    scale_y_continuous("Root of Standardized Residuals") +
    labs(title="Scale-Location")
  
  l3 <- xyplot( sqrt(abs(.stdresid)) ~ .fitted, data=fdata,
                type=c("p","smooth"),
                main="Scale-Location",
                xlab="Fitted Value",
                ylab=as.expression(
                  substitute(sqrt(abs(YL)), list(YL = as.name(ylab23)))
                )
  )
  
  # cook's distance
  g4 <-  ggplot(fdata, aes(row, .cooksd, ymin=0, ymax=.cooksd)) +
    geom_point() + geom_linerange() +
    scale_x_continuous("Observation Number") +
    scale_y_continuous("Cook's distance") +
    labs(title="Cook's Distance")
  
  l4 <- xyplot( .cooksd ~ row, data=fdata, 
                type=c("p","h"),
                main="Cook's Distance",
                xlab="Observation number",
                ylab="Cook's distance"
  )
  
  # residuals vs leverage
  g5 <- ggplot(fdata, aes(.hat, .stdresid)) +
    geom_point() +
    geom_smooth(se=FALSE) +
    geom_hline(linetype=2, size=.2) +
    scale_x_continuous("Leverage") +
    scale_y_continuous("Standardized Residuals") +
    labs(title="Residuals vs Leverage")
  
  l5 <- xyplot( .stdresid ~ .hat, data=fdata,
                type=c('p','smooth'),
                panel = function(x,y,...) {
                  panel.abline( h=0, lty=2, lwd=.5)
                  panel.xyplot( x, y, ...)
                },
                main="Residuals vs Leverage",
                xlab="Leverage",
                ylab="Standardized Residuals"
  )
  
  # cooksd vs leverage
  g6 <- ggplot(fdata, aes(.hat, .cooksd)) +
    geom_point() +
    geom_smooth(se=FALSE) +
    scale_x_continuous("Leverage") +
    scale_y_continuous("Cook's distance") +
    labs(title="Cook's dist vs Leverage")
  
  l6 <- xyplot( .cooksd ~ .hat, data=fdata,
                type = c("p", "smooth"),
                main="Cook's dist vs Leverage",
                xlab="Leverage",
                ylab="Cook's distance"
  )
  
  g7 <- mplot(summary(object, ...), system="ggplot2")
  l7 <- mplot(summary(object, ...), system="lattice")
  
  plots <- if (system == "ggplot2") {
    list(g1, g2, g3, g4, g5, g6, g7)
  } else {
    list(l1, l2, l3, l4, l5, l6, l7)
  }
  
  plots <- plots[which] 
  
  if (ask) {
    for (p in plots) {
      .devnull <- readLines("Hit <RETURN> for next plot")
      print(p)
    }
  } 
  if (multiplot) {
    return( 
      do.call(
        grid.arrange, 
        c(plots, list(...))
      )
    )
  }

  return(plots)
}

#' @rdname mplot
#' @export
#' @examples
#' mplot( HELPrct )
#' mplot( HELPrct, "histogram" )

mplot.data.frame <- function (object, default = plotTypes, system = c("lattice", "ggplot2"), 
                              show = FALSE, title = "", ..., 
                              envir=parent.frame(),
                              enclos = if (is.list(envir) || 
                                             is.pairlist(envir)) parent.frame() else baseenv()
                              ) {
  if (missing(default)) 
    default <- "scatter"
  plotTypes <- c("scatter", "jitter", "boxplot", "violin", 
                 "histogram", "density", "frequency polygon", "xyplot", 
                 "map")
  default <- match.arg(default, plotTypes)
  system <- match.arg(system)
  dataName <- substitute(object)
  if (default == "xyplot") 
    default <- "scatter"
  if (default %in% c("scatter", "jitter", "boxplot", "violin")) {
    return(eval(parse(text = paste("mScatter(", dataName, 
                                   ", default=default, system=system, show=show, title=title)")),
                envir = envir))
  }
  if (default == "map") {
    return(eval(parse(
      text = paste("mMap(", dataName, 
                   ", default=default, system=system, show=show, title=title)")),
      envir = envir))
  }
  return(eval(parse(
    text = paste("mUniplot(", dataName, 
                 ", default=default, system=system, show=show, title=title)")),
    envir = envir))
}

#' Extract data from R objects
#' 
#' @rdname fortify
#' @param model an R object to fortify
#' @param level confidence level
#' @param data a data frame (ignored by \code{fortify.summary.lm})
#' @export
fortify.summary.lm <- function(model, level=0.95, data=NULL, ...) {
  E <- as.data.frame(coef(model, level=level))
  # grab only part of the third name that comes before space
  statName <- strsplit(names(E)[3], split=" ")[[1]][1]
  names(E) <- c("estimate", "se", "stat", "pval")
  # add coefficient names to data frame
  E$coef <- row.names(E)
  E$statName <- statName
  E$lower <- confint(model, level=level, ...)[,1]
  E$upper <- confint(model, level=level, ...)[,2]
  E$level <- level
  return(E)
}

#' @rdname confint
#' @param object and R object
#' @param parm a vector of parameters
#' @param level a confidence level
#' @param ... additional arguments
#' @export
#' @examples
#' confint( summary(lm(width ~ length * sex, data=KidsFeet)) )

confint.summary.lm <- function (object, parm, level = 0.95, ...)  {
  cf <- coef(object)[, 1]
  pnames <- names(cf)
  if (missing(parm)) 
    parm <- pnames
  else if (is.numeric(parm)) 
    parm <- pnames[parm]
  a <- (1 - level)/2
  a <- c(a, 1 - a)
  fac <- qt(a, object$df[2])
  pct <- paste( format(100*a, digits=3, trim=TRUE, scientific=FALSE), "%" )
  ci <- array(NA, dim = c(length(parm), 2L), dimnames = list(parm, 
                                                             pct))
  ses <- sqrt(diag(vcov(object)))[parm]
  ci[] <- cf[parm] + ses %o% fac
  ci
}

#' @rdname mplot
#' 
#' @export
#' @examples
#' mplot(summary(lm(width ~ length * sex, data=KidsFeet)))
 
mplot.summary.lm <- function(object, 
                             system=c("lattice","ggplot2"),
                             level=0.95,
                             ...){
  
  system <- match.arg(system)
  fdata <- fortify(object, level=0.95)
  
  g <- ggplot(data=fdata,
              aes(x=factor(coef, labels=coef), y=estimate, 
                  ymin=estimate-se, ymax=estimate+se, 
                  color=log10(pval)) ) + 
    geom_pointrange() + 
    geom_hline(x=0, color="red", alpha=.5, linetype=2) + 
    labs(x="coefficient", title = paste0(format(100*level), "% confidence intervals") ) +
    coord_flip()
  
  cols <- trellis.par.get("superpose.line")$col[1 + as.numeric( sign(fdata$lower) * sign(fdata$upper) < 0)]
  l <- xyplot( factor(coef, levels=coef) ~ estimate + lower + upper,
               data=fdata,
               xlab="estimate",
               ylab="coefficient",
               main=paste0(format(100 * level), "% confidence intervals"),
               panel = function(x, y, subscripts, ...) {
                 panel.abline(v=0, col="red", alpha=.5, lty=2) 
                 panel.segments(y0=y, y1=y, x0=fdata$lower, x1=fdata$upper,
                                alpha=.6, 
                                col=cols[subscripts]
                 )
                 panel.xyplot(fdata$estimate, y, type=c('p', 'g'), 
                              cex=1.4, col=cols[subscripts])
               }
  )
  
  if (system == "ggplot2") {
    return(g)
  } else { 
    return(l)
  }
}



#' @rdname fortify
#' @param model an R object
#' @param data original data set, if needed
#' @export
#' @examples
#' fortify(TukeyHSD(lm(age ~ substance, data=HELPrct)))
 
fortify.TukeyHSD <- function(model, data, ...) {
  nms <- names(model)
  l <- length(model)
  plotData <- do.call( 
    rbind, 
    lapply(seq_len(l), function(i) {
      res <- transform(as.data.frame(model[[i]]), 
                       var=nms[[i]], 
                       pair=row.names(model[[i]]) ) 
    } ) 
  )
  names(plotData) <- c("diff", "lwr", "upr", "pval", "var", "pair")
  return(plotData)
}  

#' @rdname mplot
#' @param xlab label for x-axis
#' @param ylab label for y-axis
#' @param title title for plot
#' @export
#' @examples
#' mplot(TukeyHSD( lm(age ~ substance, data=HELPrct) ) )
#' mplot(TukeyHSD( lm(age ~ substance, data=HELPrct) ), system="ggplot2" )
mplot.TukeyHSD <- function(object, system=c("lattice", "ggplot2"), 
                           ylab="", xlab="difference in means", 
                           title="Tukey's Honest Significant Differences",
                           ...) {
  
  system = match.arg(system)
  fdata <- fortify(object)
  
  if (system=="ggplot2") {
    return(
      ggplot( data=fdata,
              aes(x=diff, color=log10(pval), y=pair) ) +
        geom_point(size=2) +
        geom_segment(aes(x=lwr, xend=upr, y=pair, yend=pair) ) +
        geom_vline( xintercept=0, color="red", linetype=2, alpha=.5 ) + 
        facet_grid( var ~ ., scales = "free_y") +
        labs(x=xlab, y=ylab, title=title)
    )
  }

  cols <- trellis.par.get("superpose.line")$col[1 + as.numeric( sign(fdata$lwr) * sign(fdata$upr) < 0)]
  return( 
    xyplot( pair ~ diff + lwr + upr | var, data=fdata, 
            panel=function(x,y,subscripts,...) {
              n <- length(x)
              m <- round(n/3)
              print(list(n=n, m=m, subscripts=subscripts))
              panel.abline(v=0, col="red", lty=2, alpha=.5)
              panel.segments(x0=x[(m+1):(2*m)], x1=x[(2*m+1):(3*m)], y0=y, y1=y, col=cols[subscripts])
              panel.xyplot(x[1:m], y, cex=1.4, pch=16, col=cols[subscripts])
            },
            scales = list( y=list(relation="free", rot=30) ),
            xlab=xlab,
            ylab=ylab,
            main=title,
            ...
    )
  )
  
}