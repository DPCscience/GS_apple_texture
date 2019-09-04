cat("Optimising training population with relatedness and clusters...\n")

# dir.create(paste0(odir, "/predictions"), showWarnings = FALSE, recursive = TRUE)
dir.create(paste0(odir, "/predictions/COLLtoFAMs_optim_kinship"), showWarnings = FALSE, recursive = TRUE)

# Predict each family with the collection
## Now we need phenos and genos_ready files
## reinitialise order of IDs
ids<-intersect(rownames(phenos), rownames(genos_ready)) %>% sort
IBS<-IBS[ids,ids]
A<-A[ids,ids]
K.Add<-K.Add[ids,ids]
NbID<-length(ids)
cat("Number of common genos/phenos: \n")
print(NbID)
phenos<-phenos[ids,]
genos_pred<-genos_ready[ids,]
nrow(phenos) == nrow(genos_pred)
## simple rrBLUP

## list of IDs in collection and family names
families<-c("FjDe", "FuPi", "FjPL", "GDFj", "GaPi", "GaPL")
NbFAM<-length(families)
WhichCOL<-c(1:NbID)[-c(lapply(families, function(x) grep(x, ids) ) %>% unlist)]
summary(rownames(genos_pred)[WhichCOL] == rownames(phenos)[WhichCOL]) ## 232 with same names

traits=colnames(phenos)
accuracy<-data.frame(FAM=rep(families, length(traits)), trait=lapply(traits, function(x) rep(x, NbFAM)) %>% unlist,accuracy=NA)

##############################
### INCREASING RELATEDNESS ###
##############################
## run predictions with 10 IDs to whole collection 

pred_rel<-function(K,Name) {
  results<-list()
  for (trait in traits) {
    tot_length=length(c(10:length(WhichCOL))) * length(families)
    results[[trait]]<-matrix(NA, nrow=tot_length,ncol=4,
                             dimnames=list(c(1:tot_length), c("size_TRS", "family","mean_rel", "accuracy")))
    counter=0
    for (fam in families) {
      WhichVS<-c(1:NbID)[grep(fam, ids)]
      kin_sel<- apply(K[WhichVS,WhichCOL],2,mean) 
      for (nb_col in c(10:length(WhichCOL))) {
        counter=counter+1
        selection<-order(kin_sel, decreasing = T)[1:nb_col]
        mean_rel<-mean(kin_sel[selection])
        print(mean_rel)
        WhichTRS<- names(kin_sel)[selection]
        res <- mixed.solve(y=phenos[WhichTRS,trait],Z=genos_pred[WhichTRS,])
        Y_VS_pred<- as.vector(genos_pred[WhichVS,] %*% as.matrix(res$u))
        acc<-cor(phenos[WhichVS, trait], Y_VS_pred, use="na.or.complete")
        print(c(trait, fam, nb_col, mean_rel,round(acc, digits=2)))
        results[[trait]][counter,]<-c(nb_col,fam, mean_rel, round(acc, digits=3))
        rm(res, Y_VS_pred,mean_rel)   
      }
      rm(WhichVS)
    }
    names(results[[trait]])<-c("nb_col", "fam", "mean_rel", "acc")
  }
  # return(results)
  saveRDS(results, file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/",Name,"_TRS_opt_all_traits.rds"))
}

pred_rel(A, "A.mat")
K=A
Name="A.mat"
results<-readRDS(paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/",Name,"_TRS_opt_all_traits.rds"))
# saveRDS(results, file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/IBS_TRS_opt_all_traits.rds"))

plot(data=results[[traits[1]]], accuracy %>% as.character %>% as.numeric ~ mean_rel  %>% as.character %>% as.numeric  )
plot(data=results[[traits[1]]], accuracy %>% as.character %>% as.numeric ~ size_TRS  %>% as.character %>% as.numeric  )
head(results[[traits[1]]])



## select 1 trait with low heritability, one with high and the PC1
sel_traits<- traits[c(3,11,13,14)]

lapply(sel_traits,function(trait) {
  pdf(file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/", trait, "_TRS_opt_size.pdf"), height=5, width=8)
  
  par(mfrow=c(2:3), mar=c(rep(5,4)))
  lapply(families, function(x) {
  data=results[[trait]] %>% as.data.frame()
  print(summary(data))
  data=data[which(data$family==x),]
  data$mean_rel
  plot(data=data, accuracy %>% as.character %>% as.numeric ~ size_TRS  %>% as.character %>% as.numeric,
       xlab="size_TRS", ylab="", main=paste(trait, x ), ylim=c(-0.5,1), cex=0.2) %>% print
  axis(side = 2) %>% print
  mtext("correlation", side = 2, line = 3, cex=0.75) %>% print
  par(new = TRUE)
  plot(data=data, mean_rel %>% as.character %>% as.numeric ~ size_TRS  %>% as.character %>% as.numeric,
       type = "l", xaxt = "n", yaxt = "n",
       xlab="", ylab="", main=paste(trait, x ), col="red", ylim=c(-0.09,0.25))  %>% print
  axis(side = 4) %>% print
  mtext("mean_relatedness", side = 4, line = 3, cex=0.75, col="red") %>% print
  abline(a=0, b=0)
  })
  dev.off()
})

lapply(sel_traits,function(trait) {
  par(mfrow=c(2:3))
  # pdf(file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/", trait, "_TRS_opt_size.pdf"))
  lapply(families, function(x) {
    data=results[[trait]] %>% as.data.frame()
    print(head(data))
    data=data[which(data$family==x),]
    plot(data=data, accuracy %>% as.character %>% as.numeric ~ mean_rel  %>% as.character %>% as.numeric,
         xlab="mean_relatedness", ylab="accuracy", main=paste(trait, x ), xlim=c(-0.17, -0.02)) %>% print
  })
  # dev.off()
})

## summarize information
## accuracy with whole collection, accuracy max and its mean_relatedness ("acc_max_rel") and TRS size, and accuracy at max relatedness ("rel_max_acc")
## we have N trait F families
# there can be several values selected
# take always the min size and relatedness  and the max accuracy
NB_traits<-length(traits)
NB_families<-length(families)
sum_res<-matrix(NA, nrow=NB_traits * NB_families , ncol=9, 
                dimnames=list(c(1:(NB_traits * NB_families)), 
                              c("trait", "fam", "acc_COL", "acc_max", "acc_max_rel", "acc_max_size", "rel_max", "rel_max_acc", "rel_max_size" ) ))
counter=0
for (trait in traits) {
  data0=results[[trait]] %>% as.data.frame()
  data0$accuracy<- data0$accuracy %>% as.character %>% as.numeric
  data0$mean_rel<- data0$mean_rel %>% as.character %>% as.numeric
  data0$size_TRS<- data0$size_TRS %>% as.character %>% as.numeric
  for(x in families) {
    counter=counter+1
    data=data0[which(data0$family==x),]
    acc_col<-data[nrow(data),"accuracy"]
    acc_max<-max(data$accuracy)
    acc_max_rel<-data[which(data$accuracy == acc_max), "mean_rel"]
    if(length(acc_max_rel) >  1) { acc_max_rel <- acc_max_rel %>% min } else { acc_max_rel= acc_max_rel}
    acc_max_size<-data[which(data$accuracy == acc_max), "size_TRS"] 
    if(length(acc_max_size) >  1) { acc_max_size <- acc_max_size %>% min } else { acc_max_size= acc_max_size}
    rel_max<-max(data$mean_rel) 
    rel_max_acc<-data[which(data$mean_rel == rel_max), "accuracy"] 
    if(length(rel_max_acc) >  1) { rel_max_acc <- rel_max_acc %>% max } else { rel_max_acc= rel_max_acc}
    rel_max_size<-data[which(data$mean_rel == rel_max), "size_TRS"] 
    if(length(rel_max_size) >  1) { rel_max_size <- rel_max_size %>% min } else {rel_max_size= rel_max_size}
    print(counter)
    sum_res[counter,]<-c(trait, x, acc_col, acc_max, acc_max_rel  %>% round(., digits=3), acc_max_size, rel_max %>% round(., digits=3), rel_max_acc, rel_max_size)
  }
  write.table(sum_res, file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/summary_results.txt"), row.names=F, quote=F, sep="\t")
}

#####################################
### INCREASING NUMBER OF CLUSTERS ###
#####################################
clusters<-read.table("~/mnt/agroscope_os/2/2/6/1/1/4/6021/GenSel_Costa_collab/R_output/20190816/genos_modelled/assignments_COLL_DAPC.txt", h=T)
rownames(clusters)<-clusters$Name
summary(clusters)
clusters<-clusters[ids[WhichCOL],] ## put the right order
head(cluster_fams)

pred_clust<-function(clusters) {
  results<-list()
  for (trait in traits) {
    tot_length=length(levels(as.factor(clusters$Cluster))) * length(families)
    results[[trait]]<-matrix(NA, nrow=tot_length,ncol=5,
                             dimnames=list(c(1:tot_length), c("nb_clusters", "size_TRS", "family","mean_rel", "accuracy")))
    counter=0
    for (fam in families) {
      WhichVS<-c(1:NbID)[grep(fam, ids)]
      kin_sel<- data.frame(mean_rel=apply(K[WhichVS,WhichCOL],2,mean))
      kin_sel$cluster<-clusters[ids[WhichCOL],"Cluster"]
      cluster_sel<- aggregate(kin_sel$mean_rel,by=list(kin_sel$cluster),FUN=mean)
      colnames(cluster_sel)<-c("cluster", "mean_rel")
      cluster_sel<-cluster_sel[order(cluster_sel$mean_rel, decreasing=T),]
      for (nb_clust in 1:length(levels(as.factor(clusters$Cluster))) ) {
        counter=counter+1
        selection<-cluster_sel$cluster[1:nb_clust] %>% as.character
        mean_rel<-mean(cluster_sel[cluster_sel$cluster %in% selection,"mean_rel" ])
        print(mean_rel)
        WhichTRS<- clusters[which(clusters$Cluster %in% selection), "Name"] %>% as.character
        res <- mixed.solve(y=phenos[WhichTRS,trait],Z=genos_pred[WhichTRS,])
        Y_VS_pred<- as.vector(genos_pred[WhichVS,] %*% as.matrix(res$u))
        acc<-cor(phenos[WhichVS, trait], Y_VS_pred, use="na.or.complete")
        print(c(trait, fam, nb_clust,selection, mean_rel,round(acc, digits=2)))
        results[[trait]][counter,]<-c(nb_clust,length(WhichTRS), fam, mean_rel, round(acc, digits=3))
        rm(res, Y_VS_pred,mean_rel)   
      }
      rm(WhichVS)
    }
    names(results[[trait]])<-c("nb_col", "fam", "mean_rel", "acc")
  }
  # return(results)
  saveRDS(results, file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/",Name,"_TRS_opt_CLUSTERS_all_traits.rds"))
}

pred_clust(clusters)

results<-readRDS(paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/",Name,"_TRS_opt_CLUSTERS_all_traits.rds"))

## select 1 trait with low heritability, one with high and the PC1
sel_traits<- traits[c(3,11,13,14)]

lapply(sel_traits,function(trait) {
  pdf(file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/", trait, "_TRS_opt_CLUSTERS.pdf"), height=5, width=8)
  
  par(mfrow=c(2:3), mar=c(rep(5,4)))
  lapply(families, function(x) {
    data=results[[trait]] %>% as.data.frame()
    print(summary(data))
    data=data[which(data$family==x),]
    plot(data=data, accuracy %>% as.character %>% as.numeric ~ size_TRS  %>% as.character %>% as.numeric,
         xlab="size_TRS", ylab="", main=paste(trait, x ), ylim=c(-0.5,1), cex=1) %>% print
    lines(y=data$accuracy %>% as.character %>% as.numeric , x= data$size_TRS  %>% as.character %>% as.numeric)
    axis(side = 2) %>% print
    mtext("correlation", side = 2, line = 3, cex=0.75) %>% print
    par(new = TRUE)
    plot(data=data, mean_rel %>% as.character %>% as.numeric ~ size_TRS  %>% as.character %>% as.numeric,
         type = "l", xaxt = "n", yaxt = "n",
         xlab="", ylab="", main=paste(trait, x ), col="red", ylim=c(-0.09,0.25))  %>% print
    axis(side = 4) %>% print
    mtext("mean_relatedness", side = 4, line = 3, cex=0.75, col="red") %>% print
    abline(a=0, b=0)
  })
  dev.off()
})

lapply(sel_traits,function(trait) {
  par(mfrow=c(2:3))
  # pdf(file=paste0(odir, "/predictions/COLLtoFAMs_optim_kinship/", trait, "_TRS_opt_size.pdf"))
  lapply(families, function(x) {
    data=results[[trait]] %>% as.data.frame()
    print(head(data))
    data=data[which(data$family==x),]
    plot(data=data, accuracy %>% as.character %>% as.numeric ~ mean_rel  %>% as.character %>% as.numeric,
         xlab="mean_relatedness", ylab="accuracy", main=paste(trait, x ), xlim=c(-0.17, -0.02)) %>% print
  })
  # dev.off()
})
# Purge obsolete variables
rm()

cat("Data modelled!\n")