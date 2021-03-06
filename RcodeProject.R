# Read Data Files

GlobalOilDemand = read.csv("GlobalOilDemand.csv", header = T)
OilProd = read.csv("OilProduction.csv", header = T)
PricePerBrl = read.csv("PricePerBarrel.csv", header = T)

# Converting to Multivariate Time Series

GlobalOilDemand.ts = ts(as.numeric(unlist(GlobalOilDemand)), start = 1980, 
                        end = 2017, frequency = 1)
OilProd.ts = ts(as.numeric(unlist(OilProd)), start = 1980, 
                end = 2017, frequency = 1)
PricePerBrl.ts = ts(as.numeric(unlist(PricePerBrl)), start = 1980,
                    end = 2017, frequency = 1)

data.ts = ts.union(GlobalOilDemand.ts,OilProd.ts, PricePerBrl.ts)

plot(data.ts, type = "l", main = "")

acf(data.ts, mar = c(3.5,3,1.9,0))
pacf(data.ts, mar = c(3.5,3,1.9,0))

# Testing for Stationarity

library(tseries)
adf.test(GlobalOilDemand.ts, alternative = "stationary")
adf.test(OilProd.ts, alternative = "stationary")
adf.test(PricePerBrl.ts, alternative = "stationary")


library(forecast)

#Determine differencing order to achieve stationarity 
ndiffs(GlobalOilDemand.ts, alpha = 0.05, test = c("adf"))
ndiffs(OilProd.ts, alpha = 0.05, test = c("adf"))
ndiffs(PricePerBrl.ts, alpha = 0.05, test = c("adf"))

#Log transformation
plot(log(data.ts), type="l",main="")

dGblOilDmd = diff(log(GlobalOilDemand.ts),differences = 1)
dOilProd = diff(log(OilProd.ts),differences = 1)
dPricePBrl = diff(log(PricePerBrl.ts),differences = 1)

ddata.ts = ts.union(dGblOilDmd, dOilProd, dPricePBrl)

plot(ddata.ts,xlab="time",main="",type="l")
acf(ddata.ts, mar=c(3.5,3,1.9,0))
pacf(ddata.ts, mar=c(3.5,3,1.9,0))

#### Data preparation for models: Testing Vs Training ###################
data=data.ts
n = nrow(data)

## Training data: 1980 to 2012
data.train=data[1:(n-5),]
## Test data: 2013 to 2017
data.test=data[(n-4):n,]

ts_GblOilDmd = ts(log(data.train[,"GlobalOilDemand.ts"]),start=1980, freq=1)
ts_OilProd = ts(log(data.train[,"OilProd.ts"]),start=1980, freq=1)
ts_PricePerBrl = ts(log(data.train[,"PricePerBrl.ts"]),start=1980, freq=1)

ts_GblOilDmd2 = ts(log(data.test[,"GlobalOilDemand.ts"]),start=2013, freq=1)
ts_OilProd2 = ts(log(data.test[,"OilProd.ts"]),start=2013, freq=1)
ts_PricePerBrl2 = ts(log(data.test[,"PricePerBrl.ts"]),start=2013, freq=1)

#### Univariate ARIMA model

final.aic = Inf
final.order = c(0,0,0,0)
for (p in 1:6) for (d in 0:1) for (q in 1:6) for(s in 0:1){
  current.aic = AIC(arima(ts_PricePerBrl, order=c(p, d, q), seasonal = list(order=c(0,s,0),
                                                                      period=1), method="ML"))
  if (current.aic < final.aic) {
    final.aic = current.aic
    final.order = c(p, d, q,s)
    
  }
}

# > final.order
# > [1] 1 0 1 1

model.arima = arima(ts_PricePerBrl, order=c(1,0,1),seasonal = list(order=c(0,1,0),
                                                             period=1), method="ML") 


## Residual analysis
par(mfrow=c(2,2))
plot(resid(model.arima), ylab='Residuals',type='o',main="Residual Plot")
abline(h=0)
acf(resid(model.arima),main="ACF: Residuals")
hist(resid(model.arima),xlab='Residuals',main='Histogram: Residuals')
qqnorm(resid(model.arima),ylab="Sample Q",xlab="Theoretical Q")
qqline(resid(model.arima))

Box.test(model.arima$resid, lag = (1+4+1), type = "Box-Pierce", fitdf = (1+4))
Box.test(model.arima$resid, lag = (1+4+1), type = "Ljung-Box", fitdf = (1+4))

#Predictions versus actual

plot(forecast(model.arima,h=5))

fore = forecast(model.arima,h=5)
fore=as.data.frame(fore)
write.csv(fore,file = "ARIMAForecast.csv")
point.fore = ts(fore[,1],start=2013, freq=1)
lo.fore = ts(fore[,4],start=2013, freq=1)
up.fore = ts(fore[,5],start=2013, freq=1)

ymin=min(c(log(unlist(PricePerBrl)[(n-4):n]),lo.fore))
ymax=max(c(log(unlist(PricePerBrl))[(n-4):n],up.fore))

plot(ts(log(as.numeric(unlist(PricePerBrl)[(n-4):n])),start=2013, freq=1), ylim=c(ymin,ymax), ylab="Log-PricePerBrl", type="l",main="")
points(point.fore,lwd=2,col="red")
lines(lo.fore,lty=3,lwd= 2, col="blue")
lines(up.fore,lty=3,lwd= 2, col="blue")

##
data.train = cbind(ts_PricePerBrl, ts_GblOilDmd, ts_OilProd)
data.test = cbind(ts_PricePerBrl2, ts_GblOilDmd2, ts_OilProd2)
##
library(vars)
###VAR Model with Deterministic Components ##
##Model Selection
VARselect(data.train, lag.max = 20,type="both")$selection

## Model Fitting: Unrestricted VAR
model.var=VAR(data.train, p=4,type="both")
summary(model.var)

## Model Fitting: Restricted VAR
model.var.restrict=restrict(model.var)  
summary(model.var.restrict)



pred = predict(model.var.restrict, n.ahead=5, ci=0.95)[[1]]$ts_PricePerBrl
point.pred = ts(pred[,1],start=2013, freq=1)
ForecastR.VAR = as.data.frame(point.pred) 
write.csv(ForecastR.VAR,file = "Forecast_Res_Var.csv")


lo.pred = ts(pred[,2],start=2013, freq=1)
up.pred = ts(pred[,3],start=2013, freq=1)
pred.f = predict(model.var,n.ahead=5, ci=0.95)[[1]]$ts_PricePerBrl
point.pred.f = ts(pred.f[,1],start=2013, freq=1)

ForecastUnrst.VAR = as.data.frame(point.pred.f) 
write.csv(ForecastUnrst.VAR,file = "Forecast_Unres_Var.csv")


lo.pred.f = ts(pred.f[,2],start=2013, freq=1)
up.pred.f = ts(pred.f[,3],start=2013, freq=1)

ymin=min(c(log(unlist(PricePerBrl)[(n-4):n]),lo.pred,lo.pred.f))
ymax=max(c(log(unlist(PricePerBrl))[(n-4):n],up.pred,up.pred.f))


plot(ts(log(as.numeric(unlist(PricePerBrl)[(n-4):n])),start=2013, freq=1), ylim=c(3,8),
     ylab="Log-PricePerBrl",type="l",main="")
points(point.pred,lwd=2,col="red")
lines(lo.pred,lty=3,lwd= 2, col="blue")
lines(up.pred,lty=3,lwd= 2, col="blue")
legend(x=2013,y = 8,legend=c("Unrestricted VAR","Restricted VAR"),pch = c(1,1)
       ,pt.cex = 1, cex = 0.8, col = c("green","red"))

points(point.pred.f,lwd=2,col="green")
lines(lo.pred.f,lty=3,lwd= 2, col="purple")
lines(up.pred.f,lty=3,lwd= 2, col="purple")
library("stats")
### Another approach for prediction & visualizing predictions
predict(model.var.restrict, n.ahead=10, ci=0.95)
fcst = forecast(model.var.restrict,h=10)
plot(fcst)
