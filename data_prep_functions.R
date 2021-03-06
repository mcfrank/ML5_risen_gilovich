# Contact: Maya Mathur (mmathur@stanford.edu)

############### FN: PREP SITE DATA ###############

# a verbose fn that preps site-level data while outputting results of sanity checks

prep_site_data = function( start.path, end.path, 
                           lkl.names, had.read.name, load.name, end.num.name,
                           eff.split.name, count.eff.name, count.hard.name, badness.name,
                           importance.name,
                           .site.name, .group,
                           .n.extra.header.rows,
                           .orig.id.name = NA ) {
  
  .d = read.csv( start.path, header=TRUE )
  
  # remove superfluous rows
  if ( .n.extra.header.rows > 0 ) {
    
    cat("\n\nExtra header rows to delete (first 3 cols):\n" )
    print( .d[ c( 1 : (.n.extra.header.rows) ), 1:3] )
    
    .d = .d[ -c( 1 : (.n.extra.header.rows) ), ]
    
    cat("\n\nFirst row of real data:\n" )
    print( head( .d[ 1, ] ) )
  } else {
    cat("\n\nNo extra header rows to delete.\n" )
  }
  
  # number of subjects
  cat( "\nRows in raw data =", dim(.d)[1] )
  
  ##### Merge Columns #####
  library(plyr)
  library(dplyr)
  lkl = coalesce( as.numeric( as.character( .d[[ lkl.names[1] ]] ) ),
                  as.numeric( as.character( .d[[ lkl.names[2] ]] ) ),
                  as.numeric( as.character( .d[[ lkl.names[3] ]] ) ),
                  as.numeric( as.character( .d[[ lkl.names[4] ]] ) ) )
  # this has the required behavior when there are NAs: e.g., coalesce( c(NA,2,NA), c(NA,NA,3) )
  
  had.read = as.numeric( as.character( .d[[ had.read.name ]] ) )
  load = as.numeric( as.character( .d[[ load.name ]] ) )
  end.num = as.numeric( as.character( .d[[ end.num.name ]] ) )
  eff.split = as.numeric( as.character( .d[[ eff.split.name ]] ) )
  count.eff = as.numeric( as.character( .d[[ count.eff.name ]] ) )
  count.hard = as.numeric( as.character( .d[[ count.hard.name ]] ) )
  badness = as.numeric( as.character( .d[[ badness.name ]] ) )
  importance = as.numeric( as.character( .d[[ importance.name ]] ) )
  
  
  ##### Skinny Data #####
  .d2 = data.frame( id=1:length(had.read),
                    .site.name, .group,
                    had.read, load, lkl,
                    eff.split, count.eff, count.hard,
                    badness, importance, end.num
  )
  
  # include original dataset id name for ease of debugging
  if( !is.na( .orig.id.name ) ) .d2$orig.id.name = .d[[.orig.id.name]]
  
  ##### Sanity Checks #####
  cat("\n\nHead of skinny dataset before exclusions:\n")
  print(head(.d2))
  
  # should not have NAs in:
  # had.read, load, or lkl (ever)
  # eff.split, count.eff, or count.hard (unless in load=0)
  flag.ids.1 = .d2$id[ is.na( .d2$had.read ) | is.na( .d2$load ) | is.na( .d2$lkl ) ]
  cat("\n\nSubjects with missing had.read, load, or lkl:", flag.ids.1 )
  
  flag.ids.2 = .d2$id[ .d2$load==1 & ( is.na( .d2$eff.split ) & is.na( .d2$eff.split ) |
                                         is.na( .d2$count.eff ) | is.na( .d2$count.hard ) ) ]
  cat("\n\nSubjects with load==1 but missing eff.split, count.eff, or count.hard:", flag.ids.2 )
  
  # people to exclude - failed to follow instructions
  bad.subj = .d2$id[ ( !is.na(.d2$eff.split) & .d2$eff.split==0 ) |
                       ( !is.na(.d2$end.num) & .d2$end.num >= 561 ) ]
  cat("\n\nBad subjects (failed to follow instructions):", bad.subj )
  
  # for debugging purposes, add columm for which subjects are to be excluded
  .d2$excluded = 0
  .d2$excluded[ .d2$id %in% bad.subj ] = 1
  # can write csv here
  #browser()
  
  # exclude bad subjects and ones missing main variables
  #  but not those missing other variables
  d3 = .d2[ !.d2$id %in% c( flag.ids.1, bad.subj ), ]
  
  # final site sample size
  d3$site.n = dim(d3)[1]
  # number of subjects
  cat( "\n\nFinal n =", dim(d3)[1] )
  
  # number excluded due to being bad subjects (rather than an empty row)
  d3$site.n.excl = length(bad.subj)
  
  # tempted-fate variable
  d3$tempt = NA
  d3$tempt[ d3$had.read==1 ] = 0
  d3$tempt[ d3$had.read==0 ] = 1
  
  ##### For Auditing Analysis #####  
  cat("\n\nMARGINAL MEANS AND SDs FOR ANALYSIS AUDIT")
  library(tableone)
  print( CreateTableOne( vars=c( "load", "tempt", "lkl" ), data=d3 ) )
  
  ##### Sneak-Preview Interaction Plot #####
  agg = ddply(d3, .(load, tempt), summarize, val = mean(lkl, na.rm=TRUE) )  # aggregate data for plotting happiness
  
  colors = c("black", "orange")
  library(ggplot2)
  plot( ggplot( d3, aes(x = as.factor(load), y = lkl, color=as.factor(tempt) ) ) +
          geom_boxplot(width=0.5) +
          geom_point(data = agg, aes(y = val), size=4 ) +
          geom_line(data = agg, aes(y = val, group = tempt), lwd=2 ) +
          scale_color_manual(values=colors) +
          scale_y_continuous( limits=c(0,10) ) +
          ggtitle(.site.name) +
          theme_bw()  + xlab("Cognitive load?") + ylab("Perceived likelihood of being called on") +
          guides(color=guide_legend(title="Tempted fate?"))
  )
  
  ##### Add Site-Specific Interaction Effect and CI #####
  m = lm( lkl ~ tempt * load, data=d3 )
  CIs = confint(m)
  
  d3$site.int.est = coef(m)["tempt:load"]
  
  d3$site.int.pval = summary(m)$coefficients["tempt:load","Pr(>|t|)"]
 
  d3$site.int.SE = sqrt( vcov(m)["tempt:load", "tempt:load"] )
  
  d3$site.int.lo = CIs["tempt:load",1]
  d3$site.int.hi = CIs["tempt:load",2]
  

  ##### Add Site-Specific Main Effect and CI #####
  d3$site.main.est = coef(m)["tempt"]
  
  d3$site.main.pval = summary(m)$coefficients["tempt","Pr(>|t|)"]
  
  d3$site.main.SE = sqrt( vcov(m)["tempt", "tempt"] )
  
  d3$site.main.lo = CIs["tempt",1]
  d3$site.main.hi = CIs["tempt",2]
  
  ##### Write Dataset #####
  string = paste( end.path, "/", "_prepped_", .site.name, ".csv", sep="" )
  write.csv( d3, string )
  invisible( d3 )
}












# prep_site_data = function( start.path, end.path, 
#                       lkl.names, had.read.name, load.name, end.num.name,
#                       eff.split.name, count.eff.name, count.hard.name, badness.name,
#                       importance.name,
#                       .site.name, .group,
#                       .n.extra.header.rows ) {
# 
#   .d = read.csv( start.path, header=TRUE )
# 
#   # remove superfluous rows
#   if ( .n.extra.header.rows > 0 ) {
#     
#     cat("\n\nExtra header rows to delete (first 3 cols):\n" )
#     print( .d[ c( 1 : (.n.extra.header.rows) ), 1:3] )
#     
#     .d = .d[ -c( 1 : (.n.extra.header.rows) ), ]
#     
#     cat("\n\nFirst row of real data:\n" )
#     print( head( .d[ 1, ] ) )
#   } else {
#     cat("\n\nNo extra header rows to delete.\n" )
#   }
#   
#   # number of subjects
#   cat( "\nRows in raw data =", dim(.d)[1] )
#   
#   ##### Merge Columns #####
#   library(plyr)
#   library(dplyr)
#   lkl = coalesce( as.numeric( as.character( .d[[ lkl.names[1] ]] ) ),
#                   as.numeric( as.character( .d[[ lkl.names[2] ]] ) ),
#                   as.numeric( as.character( .d[[ lkl.names[3] ]] ) ),
#                   as.numeric( as.character( .d[[ lkl.names[4] ]] ) ) )
#   # this has the required behavior when there are NAs: e.g., coalesce( c(NA,2,NA), c(NA,NA,3) )
#   
#   had.read = as.numeric( as.character( .d[[ had.read.name ]] ) )
#   load = as.numeric( as.character( .d[[ load.name ]] ) )
#   end.num = as.numeric( as.character( .d[[ end.num.name ]] ) )
#   eff.split = as.numeric( as.character( .d[[ eff.split.name ]] ) )
#   count.eff = as.numeric( as.character( .d[[ count.eff.name ]] ) )
#   count.hard = as.numeric( as.character( .d[[ count.hard.name ]] ) )
#   badness = as.numeric( as.character( .d[[ badness.name ]] ) )
#   importance = as.numeric( as.character( .d[[ importance.name ]] ) )
# 
#   
#   ##### Skinny Data #####
#   browser()
#   
#   # ONLY FOR DEBUGGING UCB
#   .d2 = data.frame( id=1:length(had.read), orig.id = .d[["a"]],
#                     .site.name, .group,
#                     had.read, load, lkl,
#                     eff.split, count.eff, count.hard,
#                     badness, importance, end.num
#   )
#   
#   # UNCOMMENT AFTER DEBUGGING UCB
# #   .d2 = data.frame( id=1:length(had.read), .site.name, .group,
# #                     had.read, load, lkl,
# #                     eff.split, count.eff, count.hard,
# #                     badness, importance, end.num
# #                     )
#   
#   ##### Sanity Checks #####
#   cat("\n\nHead of skinny dataset before exclusions:\n")
#   print(head(.d2))
#   
#   # should not have NAs in:
#   # had.read, load, or lkl (ever)
#   # eff.split, count.eff, or count.hard (unless in load=0)
#   flag.ids.1 = .d2$id[ is.na( .d2$had.read ) | is.na( .d2$load ) | is.na( .d2$lkl ) ]
#   cat("\n\nSubjects with missing had.read, load, or lkl:", flag.ids.1 )
#   
#   flag.ids.2 = .d2$id[ .d2$load==1 & ( is.na( .d2$eff.split ) & is.na( .d2$eff.split ) |
#                                          is.na( .d2$count.eff ) | is.na( .d2$count.hard ) ) ]
#   cat("\n\nSubjects with load==1 but missing eff.split, count.eff, or count.hard:", flag.ids.2 )
#   
#   # people to exclude - failed to follow instructions
#   bad.subj = .d2$id[ ( !is.na(.d2$eff.split) & .d2$eff.split==0 ) |
#                        ( !is.na(.d2$end.num) & .d2$end.num >= 561 ) ]
#   cat("\n\nBad subjects (failed to follow instructions):", bad.subj )
#   
#   # for debugging purposes, add columm for which subjects are to be excluded
#   .d2$excluded = 0
#   .d2$excluded[ .d2$id %in% bad.subj ] = 1
#   # can write csv here
#   #browser()
#     
#   # exclude bad subjects and ones missing main variables
#   #  but not those missing other variables
#   d3 = .d2[ !.d2$id %in% c( flag.ids.1, bad.subj ), ]
#   
#   # final site sample size
#   d3$site.n = dim(d3)[1]
#   # number of subjects
#   cat( "\n\nFinal n =", dim(d3)[1] )
#   
#   # number excluded due to being bad subjects (rather than an empty row)
#   d3$site.n.excl = length(bad.subj)
#   
#   # tempted-fate variable
#   d3$tempt = NA
#   d3$tempt[ d3$had.read==1 ] = 0
#   d3$tempt[ d3$had.read==0 ] = 1
#   
#   ##### For Auditing Analysis #####  
#   cat("\n\nMARGINAL MEANS AND SDs FOR ANALYSIS AUDIT")
#   library(tableone)
#   print( CreateTableOne( vars=c( "load", "tempt", "lkl" ), data=d3 ) )
# 
#   ##### Sneak-Preview Interaction Plot #####
#   agg = ddply(d3, .(load, tempt), summarize, val = mean(lkl, na.rm=TRUE) )  # aggregate data for plotting happiness
#   
#   colors = c("black", "orange")
#   library(ggplot2)
#   plot( ggplot( d3, aes(x = as.factor(load), y = lkl, color=as.factor(tempt) ) ) +
#           geom_boxplot(width=0.5) +
#     geom_point(data = agg, aes(y = val), size=4 ) +
#     geom_line(data = agg, aes(y = val, group = tempt), lwd=2 ) +
#     scale_color_manual(values=colors) +
#     scale_y_continuous( limits=c(0,10) ) +
#     ggtitle(.site.name) +
#     theme_bw()  + xlab("Cognitive load?") + ylab("Perceived likelihood of being called on") +
#     guides(color=guide_legend(title="Tempted fate?"))
#   )
# 
#   ##### Add Site-Specific Interaction Effect and CI #####
#   m = lm( lkl ~ tempt * load, data=d3 )
#   CIs = confint(m)
# 
#   d3$site.int.est = coef(m)["tempt:load"]
#   d3$site.main.est = coef(m)["tempt"]
# 
#   d3$site.int.lo = CIs["tempt:load",1]
#   d3$site.int.hi = CIs["tempt:load",2]
# 
#   d3$site.main.lo = CIs["tempt",1]
#   d3$site.main.hi = CIs["tempt",2]
# 
#   ##### Add Site-Specific Main Effect and CI #####
#   
#   # DO ME
#   
#   ##### Write Dataset #####
#   string = paste( end.path, "/", "_prepped_", .site.name, ".csv", sep="" )
#   write.csv( d3, string )
#   invisible( d3 )
# }






