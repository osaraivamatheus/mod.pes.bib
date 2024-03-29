# pacotes necessarios -----------------------------------------------------
library(tidyverse); library(openxlsx); library(lubridate); library(lmtest)
dados = read.xlsx('dados_brutos.xlsx', colNames = T)

# vcmh --------------------------------------------------------------------

vcmh = dados[!is.na(dados$vcmh),c(3,4)]
vcmh$periodo_vcmh = seq.Date(from = as.Date('2008-01-01'),
                             to = as.Date('2019-09-01'),
                             by = 'mon')

vcmh = vcmh %>% filter(periodo_vcmh < as.Date('2019-09-01'), periodo_vcmh >= as.Date('2012-01-01')) %>% 
  group_by(year(periodo_vcmh), quarter(periodo_vcmh)) %>% summarise(vcmh = mean(vcmh)/100)

names(vcmh) = c('ano', 'trimestre', 'vcmh')


# Tx de desocupacao -------------------------------------------------------

desocup = dados[!is.na(dados$desocupacao), c(1,2)]
desocup$periodo_desocup = seq.Date(from = as.Date('2012-01-01'),
                                         to = as.Date('2019-12-01'),
                                         by = 'quarter')
desocup$ano = year(desocup$periodo_desocup)
desocup$trimestre = quarter(desocup$periodo_desocup)
desocup$desocupacao = desocup$desocupacao/100
desocup = desocup[-32,c(3,4,2)]


# % endividamento ---------------------------------------------------------

endi = dados[, c(5,6)]
endi$periodo_endividamento = seq.Date(from = as.Date('2008-01-01'),
                                      to = as.Date('2020-03-01'),
                                      by = 'mon')
endi = endi %>% filter(periodo_endividamento <= as.Date('2019-09-01'), periodo_endividamento >= as.Date('2012-01-01') ) %>% 
  group_by(year(periodo_endividamento), quarter(periodo_endividamento)) %>% summarise(endiv = mean(endividamento)/100)

names(endi) = c('ano', 'trimestre', 'endiv')



# ipca --------------------------------------------------------------------

ipca = dados[, c(7,8)]
ipca$periodo_ipca = seq.Date(from = as.Date('2008-01-01'),
                             to = as.Date('2020-03-01'),
                             by = 'mon')
ipca  = ipca %>% filter(periodo_ipca <= as.Date('2019-09-01'), periodo_ipca >= as.Date('2012-01-01')) %>% 
  group_by(year(periodo_ipca), quarter(periodo_ipca)) %>% summarise(ipca = mean(ipca)/100)

names(ipca) = c('ano', 'trimestre', 'ipca')



# unindos bancos ------------------------------------------------------------

dados = left_join(vcmh, desocup, by = c('ano', 'trimestre'))
dados = left_join(dados, endi,  by = c('ano', 'trimestre'))
dados = left_join(dados, ipca,  by = c('ano', 'trimestre'))
dados$trimestre = seq.Date(from = as.Date('2012-01-01'),
                           to = as.Date('2019-9-01'),
                           by = 'quarter')


names(dados) = c('ano','trimestre','VCMH','DCP','ENDIV','IPCA')

# graficos ----------------------------------------------------------------

g = dados %>% pivot_longer(cols = -c(ano, trimestre), names_to = 'Variavel', values_to = 'valor') 

temporais = g %>% ggplot(aes(trimestre, valor, shape = Variavel)) + geom_line() + geom_point(size = 2) +
  xlab('') + ylab('%') + scale_shape(name = "", labels = c('DCP', 'ENDIV', 'IPCA','VCMH')) +
  theme_bw() + theme(axis.text.x = element_text(size = 16, color = 'black'),
                     axis.text.y = element_text(size = 16, color = 'black'),  
                     axis.title.x = element_text(size = 16, color = 'black'),
                     axis.title.y = element_text(size = 16, color = 'black'))

boxplots = g %>% ggplot(aes(Variavel, y = valor)) + geom_boxplot(color = 'black', fill = 'lightgrey') + theme_bw() + 
  scale_x_discrete(labels = c('DCP', 'ENDIV', 'IPCA','VCMH')) + coord_flip() + 
  xlab('') + 
   ylab('%') + theme(axis.text.x = element_text(size = 16, color = 'black'),
                    axis.text.y = element_text(size = 16, color = 'black'),  
                    axis.title.x = element_text(size = 16, color = 'black'),
                    axis.title.y = element_text(size = 16, color = 'black'),
                    legend.position = 'none')

# modelo ------------------------------------------------------------------
cor(dados[,-c(1,2)])

m = lm(VCMH ~., data = dados[,-c(1,2)])
summary(m)

shapiro.test(m$residuals)

pred = predict(m,se.fit = TRUE, interval = "confidence")
limits <- as.data.frame(pred$fit)

### reta estimada do segundo modelo
reta_est = dados[,-c(1,2)] %>% ggplot(aes(DCP, VCMH)) + geom_point(size = 2) + geom_smooth(formula = y ~ x, method = 'lm', se = F) +
  theme(axis.text.x = element_text(size = 16, color = 'black'),
        axis.text.y = element_text(size = 16, color = 'black'),  
        axis.title.x = element_text(size = 16, color = 'black'),
        axis.title.y = element_text(size = 16, color = 'black'))

t = data.frame(m$residuals )
shapiro = t %>% ggplot(aes(x = m.residuals)) + 
  geom_histogram(aes(y = ..density..), fill = 'lightgrey',
                 color = 'black',
                 bins = 6) + xlab('Resíduos') + ylab('Densidade') +
  stat_function(fun = dnorm, args = list(mean = mean(t$m.residuals), sd = sd(t$m.residuals)),
                col = 'red', size = 1.5) +
  theme(axis.text.x = element_text(size = 16, color = 'black'),
        axis.text.y = element_text(size = 16, color = 'black'),  
        axis.title.x = element_text(size = 16, color = 'black'),
        axis.title.y = element_text(size = 16, color = 'black'))


ggsave(shapiro, filename = 'shapiro.png', , width = 20, height = 14, units = "cm")
ggsave(temporais, filename = 'temporais.png', , width = 20, height = 14, units = "cm")
ggsave(boxplots, filename = 'boxplots.png', , width = 20, height = 14, units = "cm")
ggsave(reta_est, filename = 'reta_est.png', , width = 20, height = 14, units = "cm")
