library(tidyverse)
library(ggcorrplot)
library(gtools)
library(lubridate)
library(fpp3)
library(feasts)
library(patchwork)
library(slider)
library(seasonal)
library(forecast)
library(astsa)
library(tsdl)

#Predictions by Subclass

'_______GOOD________Same Process, just for MS_SubClass instead'

data <- read_csv("../data/engineered.csv")
data <- data[-1]
#Make Tidy average data frames 
#First get neighborhood and price columns, along with sale date



#date manip and adding quintile
data$date <- yearmonth(data$DateSold)
data <- data %>% mutate(ntile = ntile(SalePrice,2))
data <- data %>% select(date, ntile , SalePrice)
data$ntile <- as.factor(data$ntile)




#making a different TS 
tone <-data %>% group_by(date) %>% count() %>% as_tsibble(index = date) 
tone %>% ggplot() + geom_line(aes(x=date,y=n))+ 
  ylab("Number of Houses Sold") +
  labs(title="Ames Housing Market", subtitle= "Moving towards quantifying housing demand")
twotone <-data %>% group_by(date, ntile) %>% count() %>% as_tsibble(key = ntile, index = date) 
twotone %>% ggplot() +geom_line(aes(x=date, y=n, color=ntile)) + 
  ylab("Number of Houses Sold") + 
  labs(title="Upper and Lower Ames Housing Market", subtitle= "Notice in 2008 the trend switches; Recovery occurring in 2010" , color="2-tiles") 


data %>% group_by(date) %>% count() %>%  ungroup() %>% select(n) %>% ts() %>% acf2(main="Total Market (#) ACF/PACF")
data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '1') %>% select(n) %>%
  ts() %>% acf2(main="Upper Price Market (#) ACF/PACF")

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '2') %>% select(n) %>%
  ts() %>% acf2(main="Lower Price Market (#) ACF/PACF")

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% select(n) %>%
  ts() %>% plot.ts() #High on Top, Low on Bottom 

#FROM ACF PLOTS IT LOOKS LIKE WE NEED SOME DIFFERENCING (THERES SEASONAL SWELLS)
#No Need for log transformation since variance seems constant

####TOTAL
data %>% group_by(date) %>%
  count() %>% ungroup() %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% autoplot()


data %>% group_by(date) %>%
  count() %>% ungroup() %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1)  %>%  acf2()
#Double differencing doesnt add residue, removes trend in single differencing. 

data %>% group_by(date) %>%
  count() %>% ungroup() %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1)  %>% diff(1) %>% acf2()

#Triple differencing adds residue

###UPPER
data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '1') %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% autoplot()

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '1') %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% acf2()

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '1') %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% diff(1) %>% acf2() #Triple diff adds residue


###LOWER
data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '2') %>% select(n) %>%
  ts() %>% diff(1)  %>% diff(1)%>% autoplot()

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '2') %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% acf2()   #Double differenced 

data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '2') %>% select(n) %>%
  ts() %>% diff(1) %>% diff(1) %>% diff(1) %>% acf2() #Triple Differencing adds residue



#Ljung-Box Test 
full.dd <- data %>% group_by(date) %>%
  count() %>% ungroup() %>% select(n) %>%
  ts() %>% diff(1)  %>% diff(1)
hi.dd <-data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '1') %>% select(n) %>%
  ts() %>% diff(1)  %>% diff(1)
lo.dd<- data %>% group_by(date, ntile) %>%
  count() %>% ungroup() %>% filter(ntile == '2') %>% select(n) %>%
  ts() %>% diff(1)  %>% diff(1)

full.dd %>% Box.test(type="Ljung-Box", lag = log(nrow(full.dd))) #p = .33
hi.dd %>% Box.test(type="Ljung-Box", lag = log(nrow(hi.dd))) #p= .13
lo.dd %>% Box.test(type="Ljung-Box", lag = log(nrow(lo.dd))) #p= .21

#So we see that there's Only seasonality to this data. 

#________________________________________________Weighting the Data
#Upper, Normalized by full. 
fulltbl = data %>% group_by(date) %>%
  count()



#Creating new df
upwt <- data %>% group_by(date, ntile)  %>% summarise_at(vars(SalePrice), list(AvPrice = mean)) %>%
  arrange(desc(AvPrice)) %>% filter(ntile =='1')
lowt <- data %>% group_by(date, ntile)  %>% summarise_at(vars(SalePrice), list(AvPrice = mean)) %>%
  arrange(desc(AvPrice)) %>% filter(ntile =='2')

#Adding Weights by proportion of total demand
upwt$weight <- data %>% group_by(date, ntile) %>%
  count() %>% filter(ntile == '1') %>% ungroup() %>% select(n)/fulltbl$n
lowt$weight <- data %>% group_by(date, ntile) %>%
  count() %>% filter(ntile == '2') %>% ungroup() %>% select(n)/fulltbl$n

#Creating Weighted AveragePrice
upwt$wAvPrice <- upwt$AvPrice*upwt$weight  
lowt$wAvPrice <- lowt$AvPrice*lowt$weight  



#Weighted Prices 
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% autoplot() #needs to be Differenced
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% autoplot() #needs to be Differenced
rbind(upwt,lowt) %>% arrange(date) %>% select(c(wAvPrice, ntile)) %>%
  as_tsibble(key=ntile, index=date) %>% ggplot() + geom_line(aes(x=date, y=wAvPrice$n, color = ntile))  +labs(y='Demand (weighted Price in $)')


#__________Differencing 
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% acf2()
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(1) %>% autoplot()
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(1) %>% acf2() #Better, and residue just starts to form
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(1) %>%diff(1)  %>%acf2() 
#p=2, q=1, d=1

lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% acf2()
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(1) %>% autoplot()
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(1) %>% acf2()
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(1) %>% diff(1) %>% acf2() # Residue is worse, double diff is bad
#p=2, q=1, d=1

#d = 1
upwt.d <- upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(1)
lowt.d <- lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(1) 

#Ljung-Box Tests-----looking for p<.05 to proceed to ARIMA
upwt.d %>% Box.test(type="Ljung-Box", lag = log(length(upwt.d))) #p=.006
lowt.d %>% Box.test(type="Ljung-Box", lag = log(length(lowt.d))) #p=.013

#Therefore we have some autocorrelation that an ARIMA model can help us with



# #_________________________________________________________________________ARIMA
# #
# 
# #Upper Demand
# set <-upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()
# d =1
# p_max = 2
# q_max = 2
# for(p in 1:p_max){
#   for(q in 1:q_max){
#     if(p+q+d<=(d+q_max+p_max)){
#       model <- arima(set, order=c((p-1),d,(q-1))  ) 
#       pval <-Box.test(model$residuals, lag=log(length(model$residuals)))
#       sse = sum(model$residuals^2)
#       cat(p-1,d,q-1,'AIC: ',model$aic, 'SSE: ', sse, 'p-val: ', pval$p.value,"\n")
#       
#     }
#   }
# }
# 
# #looks like 0,1,1 model is best
# arima = arima(set, order =c(0,1,1))
# predict = forecast(arima,h=12, level=80)
# autoplot(predict, main ="ARIMA(0,1,1) Prediction on Upper Demand", ylab="Average Weighted Demand ($)")
# 
# #Lower Demand
# set <-lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()
# d =1
# p_max = 2
# q_max = 2
# for(p in 1:p_max){
#   for(q in 1:q_max){
#     if(p+q+d<=(d+q_max+p_max)){
#       model <- arima(set, order=c((p-1),d,(q-1))  ) 
#       pval <-Box.test(model$residuals, lag=log(length(model$residuals)))
#       sse = sum(model$residuals^2)
#       cat(p-1,d,q-1,'AIC: ',model$aic, 'SSE: ', sse, 'p-val: ', pval$p.value,"\n")
#       
#     }
#   }
# }
# 
# #looks like 0,1,1 model is best
# arima = arima(set, order =c(0,1,1))
# predict = forecast(arima,h=12, level=80)
# autoplot(predict, main ="ARIMA(0,1,1) Prediction on Lower Demand", ylab="Average Weighted Demand ($)")
# 

#______________________________________________________________SEASONAL DIFFERENCING
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(6) %>% diff(6) %>%  autoplot()
upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(6)  %>% diff(6) %>%  acf2()
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()%>% diff(6) %>% diff(6) %>% autoplot()
lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts() %>% diff(6) %>% acf2()


#_________Upper SARIMA
set <- upwt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()
set.ts <- upwt %>% ungroup() %>% select(c(date, Price= wAvPrice ,ntile))  %>% as_tsibble(key="ntile",index="date")
d=2
DD= 2
p_max= 3
q_max=3 
p_s_max=2
q_s_max= 2
per= 12
for(p in 1:p_max){
  for(q in 1:q_max){
    for(p_seasonal in 1:p_s_max){
      for(q_seasonal in 1:q_s_max){
        if(p+d+q+p_seasonal+DD+q_seasonal<=(p_max+q_max+p_s_max+q_s_max+d+DD)){
          model<-arima(x=set, order = c((p-1),d,(q-1)), seasonal = list(order=c((p_seasonal-1),DD,(q_seasonal-1)), period=per))
          pval<-Box.test(model$residuals, lag=log(length(model$residuals)))
          sse<-sum(model$residuals^2)
          cat(p-1,d,q-1,p_seasonal-1,DD,q_seasonal-1,per, 'AIC=', model$aic, ' SSE=',sse,' p-VALUE=', pval$p.value,'\n')
        }
      }
    }
  }
}
#want p-value to be large, we want the residuals to be normal
#Seems like SARIMA(0,2,2,1,2,0,12) is the best model 
sarima = arima(x=set, order = c(0,2,2), seasonal = list(order = c(1,2,0), period = per))
predict = forecast(sarima, h=12, level = 80)
autoplot(predict) +ylab("Demand (Weighted Price in $ (normalized by %Population))") + labs(title ="One-Year SARIMA(1,2,2,1,2,1,12) Prediction for Upper Two-Tile Housing Demand") +
  xlab("Months from Jan 2006") + ylim(c(-300000,250000))



  #________________________Train Test Split--
  #70/30 split, 55*.8=44
train <- set[1:44] %>% ts()
test <- set[45:55] %>% ts()
trueline<- ts(c(train, test),               # Combined time series object
   start = start(train),
   frequency = frequency(train))

autoplot(train) 
d=1
DD= 1
p_max= 2
q_max=2 
p_s_max=2
q_s_max= 2
per= 12
for(p in 1:p_max){
  for(q in 1:q_max){
    for(p_seasonal in 1:p_s_max){
      for(q_seasonal in 1:q_s_max){
        if(p+d+q+p_seasonal+DD+q_seasonal<=(p_max+q_max+p_s_max+q_s_max+d+DD)){
          model<-arima(x=train, order = c((p-1),d,(q-1)), seasonal = list(order=c((p_seasonal-1),DD,(q_seasonal-1)), period=per))
          pval<-Box.test(model$residuals, lag=log(length(model$residuals)))
          sse<-sum(model$residuals^2)
          cat(p-1,d,q-1,p_seasonal-1,DD,q_seasonal-1,per, 'AIC=', model$aic, ' SSE=',sse,' p-VALUE=', pval$p.value,'\n')
        }
      }
    }
  }
}

sarima_train = arima(x=train, order = c(0,1,1), seasonal = list(order = c(0,1,0), period = per))
pastpredict = forecast(sarima_train, h=length(test), level=80)
predictline <- ts(c(train, pastpredict$mean),               # Combined time series object
   start = start(train),
   frequency = frequency(train)) %>% as_tsibble()
trueline %>% as_tsibble() %>% ggplot() + geom_line(aes(x=index, y=value, color="r")) +geom_line(aes(x=index, y=predictline$value))

guess<- predictline %>% ts() %>% as.numeric() 
guess <- guess[56:110]
true<- trueline %>% ts() %>% as.numeric()
RMSE = sqrt(sum((guess-true)^2)/length(trueline))
cor(fitted(sarima_train), train)^2
cor(pastpredict$mean, test)^2


#_________Lower SARIMA
set <- lowt %>% ungroup()  %>% select(c(wAvPrice)) %>% unlist()%>% ts()
d= 2
DD= 2
p_max= 3
q_max=3 
p_s_max=2
q_s_max= 2
per= 12
for(p in 1:p_max){
  for(q in 1:q_max){
    for(p_seasonal in 1:p_s_max){
      for(q_seasonal in 1:q_s_max){
        if(p+d+q+p_seasonal+DD+q_seasonal<=(p_max+q_max+p_s_max+q_s_max+d+DD)){
          model<-arima(x=set, order = c((p-1),d,(q-1)), seasonal = list(order=c((p_seasonal-1),DD,(q_seasonal-1)), period=per))
          pval<-Box.test(model$residuals, lag=log(length(model$residuals)))
          sse<-sum(model$residuals^2)
          cat(p-1,d,q-1,p_seasonal-1,DD,q_seasonal-1,per, 'AIC=', model$aic, ' SSE=',sse,' p-VALUE=', pval$p.value,'\n')
        }
      }
    }
  }
}
#want p-value to be large, we want the residuals to be normal
#Seems like SARIMA(0,2,2,0,2,1,12) is the best model 
sarima = arima(x=set, order = c(0,2,2), seasonal = list(order = c(0,2,1), period = per))
predict = forecast(sarima, h=12, level = 80)
autoplot(predict) +ylab("Demand (Weighted Price in $ (normalized by %Population))")  + labs(title ="One-Year SARIMA(1,2,1,1,2,1,12) Prediction for Lower Two-Tile Housing Demand") +
  xlab("Months from Jan 2006") + ylim(c(-300000,250000))



#________________________Train Test Split--
#70/30 split, 55*.8=44
train <- set[1:44] %>% ts()
test <- set[45:55] %>% ts()
trueline<- ts(c(train, test),               # Combined time series object
              start = start(train),
              frequency = frequency(train))

autoplot(train) 
d=1
DD= 1
p_max= 2
q_max=2 
p_s_max=2
q_s_max= 2
per= 12
for(p in 1:p_max){
  for(q in 1:q_max){
    for(p_seasonal in 1:p_s_max){
      for(q_seasonal in 1:q_s_max){
        if(p+d+q+p_seasonal+DD+q_seasonal<=(p_max+q_max+p_s_max+q_s_max+d+DD)){
          model<-arima(x=train, order = c((p-1),d,(q-1)), seasonal = list(order=c((p_seasonal-1),DD,(q_seasonal-1)), period=per))
          pval<-Box.test(model$residuals, lag=log(length(model$residuals)))
          sse<-sum(model$residuals^2)
          cat(p-1,d,q-1,p_seasonal-1,DD,q_seasonal-1,per, 'AIC=', model$aic, ' SSE=',sse,' p-VALUE=', pval$p.value,'\n')
        }
      }
    }
  }
}

sarima_train = arima(x=train, order = c(0,1,1), seasonal = list(order = c(0,1,0), period = per))
pastpredict = forecast(sarima_train, h=length(test), level=80)
predictline <- ts(c(train, pastpredict$mean),               # Combined time series object
                  start = start(train),
                  frequency = frequency(train)) %>% as_tsibble()
trueline %>% as_tsibble() %>% ggplot() + geom_line(aes(x=index, y=value, color="r")) +geom_line(aes(x=index, y=predictline$value))

guess<- predictline %>% ts() %>% as.numeric() 
guess <- guess[56:110]
true<- trueline %>% ts() %>% as.numeric()
RMSE = sqrt(sum((guess-true)^2)/length(trueline))
cor(fitted(sarima_train), train)^2
cor(pastpredict$mean, test)^2

