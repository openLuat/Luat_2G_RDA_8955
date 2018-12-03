--- 模块功能：APN设置功能测试.
-- 重要提醒！！！！！！
-- 本模块只是简单的演示如何设置APN，并不能保证本文件中所有国外APN的正确性和完整性
-- 如果客户的产品在国外使用
-- 一定要根据当地实际的运营商网络增删改本文件中的apnTable中的项，并且用当地的卡实际测试验证
-- @author openLuat
-- @module adc.testAdc
-- @license MIT
-- @copyright openLuat
-- @release 2018.06.13

require"sim"
require"link"

module(...,package.seeall)

local apnTable =
{
    --中国大陆
    ["46000"] = {"CMIOT","",""},
    ["46002"] = {"CMIOT","",""},
    ["46004"] = {"CMIOT","",""},
    ["46007"] = {"CMIOT","",""},
    ["46008"] = {"CMIOT","",""},
    ["46001"] = {"UNINET","",""},
    ["46006"] = {"UNINET","",""},
    
    --英国
    ["23403"] = {"airtel-ci-gprs.com","",   ""},
    ["23426"] = {"data.lycamobile.co.uk",   "lmuk",   "plus"},
    ["23401"] = {"internet",   "",   ""},   
    ["23410"] = {"payandgo.o2.co.uk",   "payandgo",   "password"},   
    ["23415"] = {"pp.vodafone.co.uk",   "wap",   "wap"},   
    ["23420"] = {"three.co.uk",   "",   ""},   
    ["23430"] = {"goto.virginmobile.uk",   "",   ""},   
    ["23431"] = {"general.t-mobile.uk",   "t-mobile",   "tm"},   
    ["23432"] = {"general.t-mobile.uk",   "t-mobile",   "tm"},
    --根西岛
    ["23415"] = {"payg.talkmobile.co.uk",   "wap",   "wap"},  
    ["23415"] = {"uk.lebara.mobi",   "wap",   ""},   
    ["23415"] = {"talkmobile.co.uk",   "wap",   "wap"},   
    ["23415"] = {"asdamobiles.co.uk",   "",   ""},   
    ["23415"] = {"mobile.talktalk.co.uk",   "wap",   "wap"},
    ["23402"] = {"mobile.o2.co.uk",   "O2web",   "O2web"},   
    ["23409"] = {"internet",   "",   ""},   
    ["23409"] = {"data2.gprs.cw.com",   "",   ""},   
    ["23430"] = {"everywhere",   "eesecure",   "secure"},   
    ["23433"] = {"everywhere",   "eesecure",   "secure"},   
    ["23434"] = {"orangeinternet",   "",   ""},   
    ["23450"] = {"pepper",   "",   ""},   
    ["23455"] = {"internet",   "",   ""},   
    ["23455"] = {"data2.gprs.cw.com",   "",   ""},   
    ["23458"] = {"internet",   "",   ""},   
    ["23458"] = {"web.prontogo.net",   "webgo",   "webgo"},   
    ["23486"] = {"orangeinternet",   "",   ""},
    
    --俄罗斯
    ["25001"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25004"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25005"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25010"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25013"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25039"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25092"] = {"wap.mts.ru",   "mts",   "mts"},   
    ["25093"] = {"wap.mts.ru",   "mts",   "mts"}, 
    ["25001"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25002"] = {"internet",   "gdata",   "gdata"},   
    ["25004"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25005"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25007"] = {"internet.smarts.ru",   "any",   "any"},   
    ["25010"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25011"] = {"internet.beeline.ru",   "beeline",   "beeline"},   
    ["25012"] = {"inet.bwc.ru",   "bwc",   "bwc"},   
    ["25013"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25017"] = {"internet.usi.ru",   "",   ""},   
    ["25020"] = {"internet.tele2.ru",   "",   ""},   
    ["25028"] = {"internet.beeline.ru",   "beeline",   "beeline"},   
    ["25035"] = {"inet.ycc.ru",   "",   ""},   
    ["25039"] = {"www.usi.ru",   "u-tel",   "u-tel"},   
    ["25044"] = {"internet.beeline.ru",   "beeline",   "beeline"},   
    ["25092"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25093"] = {"internet.mts.ru",   "mts",   "mts"},   
    ["25099"] = {"internet.beeline.ru",   "beeline",   "beeline"},   

    --印度
    ["40473"] = {"bsnllive",   "",   ""},   
    ["40457"] = {"bsnllive",   "",   ""},   
    ["40471"] = {"bsnllive",   "",   ""},   
    ["40466"] = {"bsnllive",   "",   ""},   
    ["40480"] = {"bsnllive",   "",   ""},   
    ["40434"] = {"bsnllive",   "",   ""},   
    ["40472"] = {"bsnllive",   "",   ""},   
    ["40458"] = {"bsnllive",   "",   ""},   
    ["40453"] = {"bsnllive",   "",   ""},   
    ["40459"] = {"bsnllive",   "",   ""},   
    ["40455"] = {"bsnllive",   "",   ""},   
    ["40454"] = {"bsnllive",   "",   ""},   
    ["40474"] = {"bsnllive",   "",   ""},   
    ["40438"] = {"bsnllive",   "",   ""},   
    ["40475"] = {"bsnllive",   "",   ""},   
    ["40451"] = {"bsnllive",   "",   ""},   
    ["40462"] = {"bsnllive",   "",   ""},   
    ["40477"] = {"bsnllive",   "",   ""},   
    ["40476"] = {"bsnllive",   "",   ""},   
    ["40464"] = {"bsnllive",   "",   ""},   
    ["40481"] = {"bsnllive",   "",   ""},   
    ["40449"] = {"airtelfun.com",   "",   ""},   
    ["40498"] = {"airtelfun.com",   "",   ""},   
    ["40445"] = {"airtelfun.com",   "",   ""},   
    ["40490"] = {"airtelfun.com",   "",   ""},   
    ["40494"] = {"airtelfun.com",   "",   ""},   
    ["40496"] = {"airtelfun.com",   "",   ""},   
    ["40495"] = {"airtelfun.com",   "",   ""},   
    ["40493"] = {"airtelfun.com",   "",   ""},   
    ["40402"] = {"airtelfun.com",   "",   ""},   
    ["40470"] = {"airtelfun.com",   "",   ""},   
    ["40497"] = {"airtelfun.com",   "",   ""},   
    ["40403"] = {"airtelfun.com",   "",   ""},   
    ["40416"] = {"airtelfun.com",   "",   ""},   
    ["40440"] = {"airtelfun.com",   "",   ""},   
    ["40410"] = {"airtelfun.com",   "",   ""},   
    ["40431"] = {"airtelfun.com",   "",   ""},   
    ["40492"] = {"airtelfun.com",   "",   ""},   
    ["40413"] = {"portalnmms",   "",   ""},   
    ["40405"] = {"portalnmms",   "",   ""},   
    ["40486"] = {"portalnmms",   "",   ""},   
    ["40427"] = {"portalnmms",   "",   ""},   
    ["40443"] = {"portalnmms",   "",   ""},   
    ["40401"] = {"portalnmms",   "",   ""},   
    ["40446"] = {"portalnmms",   "",   ""},   
    ["40488"] = {"portalnmms",   "",   ""},   
    ["40460"] = {"portalnmms",   "",   ""},   
    ["40415"] = {"portalnmms",   "",   ""},   
    ["40484"] = {"portalnmms",   "",   ""},   
    ["40411"] = {"portalnmms",   "",   ""},   
    ["40430"] = {"portalnmms",   "",   ""},   
    ["40420"] = {"portalnmms",   "",   ""},   
    ["40442"] = {"aircelwap",   "",   ""},   
    ["40417"] = {"aircelwap",   "",   ""},   
    ["40429"] = {"aircelwap",   "",   ""},   
    ["40425"] = {"aircelwap",   "",   ""},   
    ["40435"] = {"aircelwap",   "",   ""},   
    ["40437"] = {"aircelwap",   "",   ""},   
    ["40433"] = {"aircelwap",   "",   ""},   
    ["40428"] = {"aircelwap",   "",   ""},   
    ["40441"] = {"aircelwap",   "",   ""},   
    ["40491"] = {"aircelwap",   "",   ""},   
    ["40407"] = {"imis",   "",   ""},   
    ["40424"] = {"imis",   "",   ""},   
    ["40404"] = {"imis",   "",   ""},   
    ["40422"] = {"imis",   "",   ""},   
    ["40412"] = {"imis",   "",   ""},   
    ["40419"] = {"imis",   "",   ""},   
    ["40478"] = {"imis",   "",   ""},   
    ["40414"] = {"imis",   "",   ""},   
    ["40487"] = {"imis",   "",   ""},   
    ["40489"] = {"imis",   "",   ""},   
    ["40456"] = {"imis",   "",   ""},   
    ["40482"] = {"imis",   "",   ""},   
    ["40444"] = {"imis",   "",   ""},   
    ["40468"] = {"mtnl.net",   "mtnl",   "mtnl123"},   
    ["40469"] = {"mtnl.net",   "",   ""},   
    ["40421"] = {"www",   "",   ""},   
    ["40421"] = {"mizone",   "919821099800",   "mmsc"},   
    ["40421"] = {"mizone",   "919821099800",   "mmsc"},   
    ["40483"] = {"smartwap",   "",   ""},   
    ["40485"] = {"smartwap",   "",   ""},   
    ["40467"] = {"smartwap",   "",   ""},   
    ["40409"] = {"smartwap",   "",   ""},   
    ["40436"] = {"smartwap",   "",   ""},   
    ["40418"] = {"smartwap",   "",   ""},   
    ["40450"] = {"smartwap",   "",   ""},   
    ["40452"] = {"smartwap",   "",   ""},  
    ["40473"] = {"bsnlnet",   "",   ""},   
    ["40457"] = {"bsnlnet",   "",   ""},   
    ["40471"] = {"bsnlnet",   "",   ""},   
    ["40466"] = {"bsnlnet",   "",   ""},   
    ["40480"] = {"bsnlnet",   "",   ""},   
    ["40434"] = {"bsnlnet",   "",   ""},   
    ["40472"] = {"bsnlnet",   "",   ""},   
    ["40458"] = {"bsnlnet",   "",   ""},   
    ["40453"] = {"bsnlnet",   "",   ""},   
    ["40459"] = {"bsnlnet",   "",   ""},   
    ["40455"] = {"bsnlnet",   "",   ""},   
    ["40454"] = {"bsnlnet",   "",   ""},   
    ["40474"] = {"bsnlnet",   "",   ""},   
    ["40438"] = {"bsnlnet",   "",   ""},   
    ["40475"] = {"bsnlnet",   "",   ""},   
    ["40451"] = {"bsnlnet",   "",   ""},   
    ["40462"] = {"bsnlnet",   "",   ""},   
    ["40477"] = {"bsnlnet",   "",   ""},   
    ["40476"] = {"bsnlnet",   "",   ""},   
    ["40464"] = {"bsnlnet",   "",   ""},   
    ["40481"] = {"bsnlnet",   "",   ""},   
    ["40449"] = {"airtelgprs.com",   "",   ""},   
    ["40498"] = {"airtelgprs.com",   "",   ""},   
    ["40445"] = {"airtelgprs.com",   "",   ""},   
    ["40490"] = {"airtelgprs.com",   "",   ""},   
    ["40494"] = {"airtelgprs.com",   "",   ""},   
    ["40496"] = {"airtelgprs.com",   "",   ""},   
    ["40495"] = {"airtelgprs.com",   "",   ""},   
    ["40493"] = {"airtelgprs.com",   "",   ""},   
    ["40402"] = {"airtelgprs.com",   "",   ""},   
    ["40470"] = {"airtelgprs.com",   "",   ""},   
    ["40497"] = {"airtelgprs.com",   "",   ""},   
    ["40403"] = {"airtelgprs.com",   "",   ""},   
    ["40416"] = {"airtelgprs.com",   "",   ""},   
    ["40440"] = {"airtelgprs.com",   "",   ""},   
    ["40410"] = {"airtelgprs.com",   "",   ""},   
    ["40431"] = {"airtelgprs.com",   "",   ""},   
    ["40492"] = {"airtelgprs.com",   "",   ""},   
    ["40413"] = {"www",   "",   ""},   
    ["40405"] = {"www",   "",   ""},   
    ["40486"] = {"www",   "",   ""},   
    ["40427"] = {"www",   "",   ""},   
    ["40443"] = {"www",   "",   ""},   
    ["40401"] = {"www",   "",   ""},   
    ["40446"] = {"www",   "",   ""},   
    ["40488"] = {"www",   "",   ""},   
    ["40460"] = {"www",   "",   ""},   
    ["40415"] = {"www",   "",   ""},   
    ["40484"] = {"www",   "",   ""},   
    ["40411"] = {"www",   "",   ""},   
    ["40430"] = {"www",   "",   ""},   
    ["40420"] = {"www",   "",   ""},   
    ["40442"] = {"aircelgprs",   "",   ""},   
    ["40417"] = {"aircelgprs",   "",   ""},   
    ["40429"] = {"aircelgprs",   "",   ""},   
    ["40425"] = {"aircelgprs",   "",   ""},   
    ["40435"] = {"aircelgprs",   "",   ""},   
    ["40437"] = {"aircelgprs",   "",   ""},   
    ["40433"] = {"aircelgprs",   "",   ""},   
    ["40428"] = {"aircelgprs",   "",   ""},   
    ["40441"] = {"aircelgprs",   "",   ""},   
    ["40491"] = {"aircelgprs",   "",   ""},   
    ["40407"] = {"internet",   "",   ""},   
    ["40424"] = {"internet",   "",   ""},   
    ["40404"] = {"internet",   "",   ""},   
    ["40422"] = {"internet",   "",   ""},   
    ["40412"] = {"internet",   "",   ""},   
    ["40419"] = {"internet",   "",   ""},   
    ["40478"] = {"internet",   "",   ""},   
    ["40414"] = {"internet",   "",   ""},   
    ["40487"] = {"internet",   "",   ""},   
    ["40489"] = {"internet",   "",   ""},   
    ["40456"] = {"internet",   "",   ""},   
    ["40482"] = {"internet",   "",   ""},   
    ["40444"] = {"internet",   "",   ""},   
    ["40468"] = {"mtnl.net",   "mtnl",   "mtnl123"},   
    ["40469"] = {"mtnl.net",   "",   ""},   
    ["40483"] = {"smartnet",   "",   ""},   
    ["40485"] = {"smartnet",   "",   ""},   
    ["40467"] = {"smartnet",   "",   ""},   
    ["40409"] = {"smartnet",   "",   ""},   
    ["40436"] = {"smartnet",   "",   ""},   
    ["40418"] = {"smartnet",   "",   ""},   
    ["40450"] = {"smartnet",   "",   ""},   
    ["40452"] = {"smartnet",   "",   ""},
    ["40554"] = {"airtelfun.com",   "",   ""},   
    ["40551"] = {"airtelfun.com",   "",   ""},   
    ["40556"] = {"airtelfun.com",   "",   ""},   
    ["40552"] = {"airtelfun.com",   "",   ""},   
    ["40555"] = {"airtelfun.com",   "",   ""},   
    ["40553"] = {"airtelfun.com",   "",   ""},   
    ["405756"] = {"portalnmms",   "",   ""},   
    ["40566"] = {"portalnmms",   "",   ""},   
    ["40567"] = {"portalnmms",   "",   ""},   
    ["405751"] = {"portalnmms",   "",   ""},   
    ["405752"] = {"portalnmms",   "",   ""},   
    ["405754"] = {"portalnmms",   "",   ""},   
    ["405750"] = {"portalnmms",   "",   ""},   
    ["405755"] = {"portalnmms",   "",   ""},   
    ["405753"] = {"portalnmms",   "",   ""},   
    ["405801"] = {"aircelwap",   "",   ""},   
    ["405802"] = {"aircelwap",   "",   ""},   
    ["405803"] = {"aircelwap",   "",   ""},   
    ["405804"] = {"aircelwap",   "",   ""},   
    ["405807"] = {"aircelwap",   "",   ""},   
    ["405809"] = {"aircelwap",   "",   ""},   
    ["405808"] = {"aircelwap",   "",   ""},   
    ["405812"] = {"aircelwap",   "",   ""},   
    ["405806"] = {"aircelwap",   "",   ""},   
    ["405810"] = {"aircelwap",   "",   ""},   
    ["405811"] = {"aircelwap",   "",   ""},   
    ["405800"] = {"aircelwap",   "",   ""},   
    ["405805"] = {"aircelwap",   "",   ""},   
    ["405852"] = {"imis",   "",   ""},   
    ["405853"] = {"imis",   "",   ""},   
    ["405845"] = {"imis",   "",   ""},   
    ["40570"] = {"imis",   "",   ""},   
    ["405846"] = {"imis",   "",   ""},   
    ["405849"] = {"imis",   "",   ""},   
    ["405850"] = {"imis",   "",   ""},   
    ["405848"] = {"imis",   "",   ""},   
    ["405799"] = {"imis",   "",   ""},   
    ["405854"] = {"www",   "",   ""},   
    ["405858"] = {"www",   "",   ""},   
    ["405862"] = {"www",   "",   ""},   
    ["405866"] = {"www",   "",   ""},   
    ["405871"] = {"www",   "",   ""},   
    ["405859"] = {"www",   "",   ""},   
    ["405863"] = {"www",   "",   ""},   
    ["405865"] = {"www",   "",   ""},   
    ["405869"] = {"www",   "",   ""},   
    ["405870"] = {"www",   "",   ""},   
    ["405872"] = {"www",   "",   ""},   
    ["405873"] = {"www",   "",   ""},   
    ["405874"] = {"www",   "",   ""},   
    ["405855"] = {"www",   "",   ""},   
    ["405856"] = {"www",   "",   ""},   
    ["405860"] = {"www",   "",   ""},   
    ["405861"] = {"www",   "",   ""},   
    ["405867"] = {"www",   "",   ""},   
    ["405868"] = {"www",   "",   ""},   
    ["405857"] = {"www",   "",   ""},   
    ["405864"] = {"www",   "",   ""},   
    ["405854"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405858"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405862"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405866"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405871"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405859"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405863"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405865"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405869"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405870"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405872"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405873"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405874"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405855"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405856"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405860"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405861"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405867"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405868"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405857"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405864"] = {"mizone",   "919821099800",   "mmsc"},   
    ["405025"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405030"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405034"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405037"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405044"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405031"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405035"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405038"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405042"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405043"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405045"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405046"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405047"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405026"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405027"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405032"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405033"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405040"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405041"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405029"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405036"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405039"] = {"TATA.DOCOMO.DIVE.IN",   "",   ""},   
    ["405819"] = {"uninor",   "",   ""},   
    ["405927"] = {"uninor",   "",   ""},   
    ["405820"] = {"uninor",   "",   ""},   
    ["405929"] = {"uninor",   "",   ""},   
    ["405925"] = {"uninor",   "",   ""},   
    ["405813"] = {"uninor",   "",   ""},   
    ["405821"] = {"uninor",   "",   ""},   
    ["405928"] = {"uninor",   "",   ""},   
    ["405816"] = {"uninor",   "",   ""},   
    ["405817"] = {"uninor",   "",   ""},   
    ["405879"] = {"uninor",   "",   ""},   
    ["405818"] = {"uninor",   "",   ""},   
    ["405880"] = {"uninor",   "",   ""},   
    ["405875"] = {"uninor",   "",   ""},   
    ["405876"] = {"uninor",   "",   ""},   
    ["405814"] = {"uninor",   "",   ""},   
    ["405815"] = {"uninor",   "",   ""},   
    ["405877"] = {"uninor",   "",   ""},   
    ["405878"] = {"uninor",   "",   ""},   
    ["405844"] = {"uninor",   "",   ""},   
    ["405822"] = {"uninor",   "",   ""},   
    ["405926"] = {"uninor",   "",   ""},   
    ["40501"] = {"rcomwap",   "",   ""},   
    ["40506"] = {"rcomwap",   "",   ""},   
    ["40510"] = {"rcomwap",   "",   ""},   
    ["40513"] = {"rcomwap",   "",   ""},   
    ["40520"] = {"rcomwap",   "",   ""},   
    ["40507"] = {"rcomwap",   "",   ""},   
    ["40511"] = {"rcomwap",   "",   ""},   
    ["40518"] = {"rcomwap",   "",   ""},   
    ["40519"] = {"rcomwap",   "",   ""},   
    ["40521"] = {"rcomwap",   "",   ""},   
    ["40522"] = {"rcomwap",   "",   ""},   
    ["40509"] = {"rcomwap",   "",   ""},   
    ["40504"] = {"rcomwap",   "",   ""},   
    ["40505"] = {"rcomwap",   "",   ""},   
    ["40515"] = {"rcomwap",   "",   ""},   
    ["405823"] = {"vgprs.com",   "",   ""},   
    ["405827"] = {"vgprs.com",   "",   ""},   
    ["405831"] = {"vgprs.com",   "",   ""},   
    ["405835"] = {"vgprs.com",   "",   ""},   
    ["405840"] = {"vgprs.com",   "",   ""},   
    ["405828"] = {"vgprs.com",   "",   ""},   
    ["405832"] = {"vgprs.com",   "",   ""},   
    ["405834"] = {"vgprs.com",   "",   ""},   
    ["405839"] = {"vgprs.com",   "",   ""},   
    ["405841"] = {"vgprs.com",   "",   ""},   
    ["405842"] = {"vgprs.com",   "",   ""},   
    ["405843"] = {"vgprs.com",   "",   ""},   
    ["405824"] = {"vgprs.com",   "",   ""},   
    ["405825"] = {"vgprs.com",   "",   ""},   
    ["405829"] = {"vgprs.com",   "",   ""},   
    ["405830"] = {"vgprs.com",   "",   ""},   
    ["405837"] = {"vgprs.com",   "",   ""},   
    ["405838"] = {"vgprs.com",   "",   ""},   
    ["405833"] = {"vgprs.com",   "",   ""},   
    ["405836"] = {"vgprs.com",   "",   ""},  
    ["405932"] = {"vinternet.com",   "",   ""},   
    ["405932"] = {"vgprs.com",   "",   ""},   
    ["405039"] = {"m.vbytes.in",   "",   ""},
    ["40554"] = {"airtelgprs.com",   "",   ""},   
    ["40551"] = {"airtelgprs.com",   "",   ""},   
    ["40556"] = {"airtelgprs.com",   "",   ""},   
    ["40552"] = {"airtelgprs.com",   "",   ""},   
    ["40555"] = {"airtelgprs.com",   "",   ""},   
    ["40553"] = {"airtelgprs.com",   "",   ""},   
    ["405756"] = {"www",   "",   ""},   
    ["40566"] = {"www",   "",   ""},   
    ["40567"] = {"www",   "",   ""},   
    ["405751"] = {"www",   "",   ""},   
    ["405752"] = {"www",   "",   ""},   
    ["405754"] = {"www",   "",   ""},   
    ["405750"] = {"www",   "",   ""},   
    ["405755"] = {"www",   "",   ""},   
    ["405753"] = {"www",   "",   ""},   
    ["405801"] = {"aircelgprs",   "",   ""},   
    ["405802"] = {"aircelgprs",   "",   ""},   
    ["405803"] = {"aircelgprs",   "",   ""},   
    ["405804"] = {"aircelgprs",   "",   ""},   
    ["405807"] = {"aircelgprs",   "",   ""},   
    ["405809"] = {"aircelgprs",   "",   ""},   
    ["405808"] = {"aircelgprs",   "",   ""},   
    ["405812"] = {"aircelgprs",   "",   ""},   
    ["405806"] = {"aircelgprs",   "",   ""},   
    ["405810"] = {"aircelgprs",   "",   ""},   
    ["405811"] = {"aircelgprs",   "",   ""},   
    ["405800"] = {"aircelgprs",   "",   ""},   
    ["405805"] = {"aircelgprs",   "",   ""},   
    ["405852"] = {"internet",   "",   ""},   
    ["405853"] = {"internet",   "",   ""},   
    ["405845"] = {"internet",   "",   ""},   
    ["40570"] = {"internet",   "",   ""},   
    ["405846"] = {"internet",   "",   ""},   
    ["405849"] = {"internet",   "",   ""},   
    ["405850"] = {"internet",   "",   ""},   
    ["405848"] = {"internet",   "",   ""},   
    ["405799"] = {"internet",   "",   ""},   
    ["405025"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405030"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405034"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405037"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405044"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405031"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405035"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405038"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405042"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405043"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405045"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405046"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405047"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405026"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405027"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405032"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405033"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405040"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405041"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405029"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405036"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405039"] = {"TATA.DOCOMO.INTERNET",   "",   ""},   
    ["405819"] = {"uninor",   "",   ""},   
    ["405927"] = {"uninor",   "",   ""},   
    ["405820"] = {"uninor",   "",   ""},   
    ["405929"] = {"uninor",   "",   ""},   
    ["405925"] = {"uninor",   "",   ""},   
    ["405813"] = {"uninor",   "",   ""},   
    ["405821"] = {"uninor",   "",   ""},   
    ["405928"] = {"uninor",   "",   ""},   
    ["405816"] = {"uninor",   "",   ""},   
    ["405817"] = {"uninor",   "",   ""},   
    ["405879"] = {"uninor",   "",   ""},   
    ["405818"] = {"uninor",   "",   ""},   
    ["405880"] = {"uninor",   "",   ""},   
    ["405875"] = {"uninor",   "",   ""},   
    ["405876"] = {"uninor",   "",   ""},   
    ["405814"] = {"uninor",   "",   ""},   
    ["405815"] = {"uninor",   "",   ""},   
    ["405877"] = {"uninor",   "",   ""},   
    ["405878"] = {"uninor",   "",   ""},   
    ["405844"] = {"uninor",   "",   ""},   
    ["405822"] = {"uninor",   "",   ""},   
    ["405926"] = {"uninor",   "",   ""},   
    ["40501"] = {"rcomnet",   "",   ""},   
    ["40506"] = {"rcomnet",   "",   ""},   
    ["40510"] = {"rcomnet",   "",   ""},   
    ["40513"] = {"rcomnet",   "",   ""},   
    ["40520"] = {"rcomnet",   "",   ""},   
    ["40507"] = {"rcomnet",   "",   ""},   
    ["40511"] = {"rcomnet",   "",   ""},   
    ["40515"] = {"rcomnet",   "",   ""},   
    ["40518"] = {"rcomnet",   "",   ""},   
    ["40519"] = {"rcomnet",   "",   ""},   
    ["40521"] = {"rcomnet",   "",   ""},   
    ["40522"] = {"rcomnet",   "",   ""},   
    ["40509"] = {"rcomnet",   "",   ""},   
    ["40504"] = {"rcomnet",   "",   ""},   
    ["40505"] = {"rcomnet",   "",   ""},   
    ["405823"] = {"vinternet.com",   "",   ""},   
    ["405827"] = {"vinternet.com",   "",   ""},   
    ["405831"] = {"vinternet.com",   "",   ""},   
    ["405835"] = {"vinternet.com",   "",   ""},   
    ["405840"] = {"vinternet.com",   "",   ""},   
    ["405828"] = {"vinternet.com",   "",   ""},   
    ["405832"] = {"vinternet.com",   "",   ""},   
    ["405834"] = {"vinternet.com",   "",   ""},   
    ["405839"] = {"vinternet.com",   "",   ""},   
    ["405841"] = {"vinternet.com",   "",   ""},   
    ["405842"] = {"vinternet.com",   "",   ""},   
    ["405843"] = {"vinternet.com",   "",   ""},   
    ["405824"] = {"vinternet.com",   "",   ""},   
    ["405825"] = {"vinternet.com",   "",   ""},   
    ["405829"] = {"vinternet.com",   "",   ""},   
    ["405830"] = {"vinternet.com",   "",   ""},   
    ["405837"] = {"vinternet.com",   "",   ""},   
    ["405838"] = {"vinternet.com",   "",   ""},   
    ["405833"] = {"vinternet.com",   "",   ""},   
    ["405836"] = {"vinternet.com",   "",   ""},   
    ["405039"] = {"vinternet.in",   "",   ""},

    --越南
    ["45201"] = {"m-wap",   "mms",   "mms"},   
    ["45204"] = {"v-internet",   "",   ""},   
    ["45205"] = {"internet",   "",   ""},   
    ["45205"] = {"wap",   "",   ""}, 
    ["45202"] = {"m3-world",   "mms",   "mms"},   
    ["45208"] = {"e-internet",   "",   ""},      

    --老挝
    ["45701"] = {"ltcnet",   "",   ""},   
    ["45708"] = {"beelinewap",   "",   ""},   
    ["45708"] = {"beelinenet",   "",   ""},  
    ["45708"] = {"beelinemms",   "",   ""},
    ["45702"] = {"etlnet",   "",   ""},   
    ["45703"] = {"unitel3g",   "",   ""},   
    
    --印度尼西亚
    ["51001"] = {"indosatgprs",   "indosat",   "indosat"},   
    ["51001"] = {"indosatgprs",   "indosat",   "indosat"},   
    ["51008"] = {"AXIS",   "AXIS",   "123456"},   
    ["51008"] = {"AXIS",   "AXIS",   "123456"},   
    ["51010"] = {"telkomsel",   "wap",   "wap123"},   
    ["51010"] = {"internet",   "",   ""},   
    ["51011"] = {"www.xlgprs.net",   "",   ""},   
    ["51011"] = {"www.xlgprs.net",   "xlgprs",   "proxl"},   
    ["51021"] = {"indosatgprs",   "indosat",   "indosat"},
    ["51089"] = {"3gprs",   "3gprs",   "3gprs"},   
    ["51089"] = {"3data",   "3data",   "3data"},     
    
    --新加坡
    ["52503"] = {"sunsurf",   "65",   "user123"},   
    ["52505"] = {"shppd",   "",   ""}, 
    ["52501"] = {"e-ideas",   "",   ""},   
    ["52502"] = {"e-ideas",   "",   ""},    

    --卢旺达
    ["63510"] = {"internet.mtn",   "",   ""},   
    ["63513"] = {"web.tigo.rw",   "",   ""},   
    ["63514"] = {"internet",   "",   ""}, 

    --马拉维
    ["65010"] = {"internet",   "",   ""},   
    ["65001"] = {"internet",   "",   ""}, 

    --智利
    ["73009"] = {"wap.netelmovil.cl",   "",   ""},  
    ["73001"] = {"imovil.entelpcs.cl",   "entelpcs",   "entelpcs"},   
    ["73003"] = {"wap.clarochile.cl",   "clarochile",   "clarochile"},   
    ["73007"] = {"imovil.virginmobile.cl",   "",   ""},   
    ["73008"] = {"movil.vtr.com",   "vtrmovil",   "vtrmovil"},   
    ["73008"] = {"bam.vtr.com",   "vtr",   "vtr"},   
    ["73010"] = {"bam.entelpcs.cl",   "entelpcs",   "entelpcs"},   
    ["73010"] = {"imovil.entelpcs.cl",   "entelpcs",   "entelpcs"},
    ["73002"] = {"wap.tmovil.cl",   "wap",   "wap"},  
    ["732101"] = {"internet.comcel.com.co",   "COMCELWEB",   "COMCELWEB"},   
    ["732102"] = {"internet.movistar.com.co",   "movistar",   "movistar"},   
    ["732103"] = {"web.colombiamovil.com.co",   "",   ""},   
    ["732111"] = {"web.colombiamovil.com.co",   "",   ""},   
    ["732123"] = {"internet.movistar.com.co",   "movistar",   "movistar"},        
    
    --韩国
    ["45006"] = {"internet.lguplus.co.kr",   "",   ""},  
    ["45002"] = {"lte.ktfwing.com",   "",   ""},   
    ["45004"] = {"alwayson-r6.ktfing.com",   "",   ""},   
    ["45008"] = {"lte.ktfwing.com",   "",   ""},   
    ["45005"] = {"web.sktelecom.com",   "",   ""},       
   
    --加拿大
    ["302220"] = {"sp.telus.com",   "",   ""},  
    ["302370"] = {"isp.fido.apn",   "",   ""},   
    ["302320"] = {"wap.davewireless.com",   "",   ""},   
    ["302490"] = {"internet.windmobile.ca",   "",   ""},   
    ["302720"] = {"isp.apn",   "",   ""},
    ["302370"] = {"fido-core-appl1.apn",   "",   ""},   
    ["302500"] = {"media.videotron",   "",   ""},   
    ["302610"] = {"pda.bell.ca",   "",   ""},   
    ["302720"] = {"rogers-core-appl1.apn",   "",   ""},   
    ["302720"] = {"internet.com",   "guest",   "guest"},   
    ["302780"] = {"pda.stm.sk.ca",   "",   ""}, 

    --肯尼亚
    ["63902"] = {"Safaricom",   "saf",   "data"},   

    --希腊
    ["20201"] = {"internet",   "",   ""},   
    ["20205"] = {"internet",   "user",   "pass"},   
    ["20205"] = {"internet.vodafone.gr",   "user",   "pass"},   
    ["20205"] = {"surfonly.vodafone.gr",   "",   ""},   
    ["20210"] = {"gint.b-online.gr",   "wap",   "wap"},   

    --荷兰
    ["20416"] = {"internet",   "*",   "*"},   
    ["20420"] = {"internet",   "",   ""},   
    ["20420"] = {"rabo.plus",   "",   ""},
    ["20404"] = {"live.vodafone.com",   "vodafone",   "vodafone"},   
    ["20408"] = {"portalmmm.nl",   "",   ""},   
    ["20412"] = {"internet",   "",   ""},       
    
    --比利时
    ["20601"] = {"internet.proximus.be",   "",   ""},   
    ["20605"] = {"telenetwap.be",   "",   ""},   
    ["20610"] = {"mworld.be",   "",   ""},   
    ["20620"] = {"gprs.base.be",   "base",   "base"},   

    --法国
    ["20800"] = {"orange-mib",   "orange",   "orange"},   
    ["20800"] = {"orange",   "orange",   "orange"},   
    ["20800"] = {"orange.fr",   "orange",   "orange"},   
    ["20801"] = {"orange",   "orange",   "orange"},   
    ["20802"] = {"orange",   "orange",   "orange"},   
    ["20802"] = {"orange.fr",   "",   ""},   
    ["20802"] = {"orange-mib",   "orange",   "orange"},   
    ["20810"] = {"sl2sfr",   "",   ""},   
    ["20811"] = {"websfr",   "",   ""},   
    ["20813"] = {"websfr",   "",   ""},   
    ["20815"] = {"free",   "",   ""},   
    ["20820"] = {"ebouygtal.com",   "",   ""},   
    ["20821"] = {"ebouygtel.com",   "",   ""},   
    ["20821"] = {"a2bouygtel.com",   "",   ""},   
    ["20888"] = {"a2bouygtel.com",   "",   ""},   
    ["20888"] = {"ebouygtel.com",   "",   ""},   

    --西班牙
    ["21401"] = {"airtelwap.es",   "wap@wap",   "airtel"},   
    ["21403"] = {"orangeworld",   "orange",   "orange"},   
    ["21404"] = {"internet",   "",   ""},   
    ["21406"] = {"airtelnet.es",   "vodafone",   "vodafone"},   
    ["21407"] = {"movistar.es",   "MOVISTAR",   "MOVISTAR"},   
    ["21408"] = {"internet.euskaltel.mobi",   "CLIENTE",   "EUSKALTEL"},   
    ["21416"] = {"internet.telecable.es",   "telecable",   "telecable"},   
    ["21422"] = {"internet",   "",   ""},
    
    --匈牙利
    ["21601"] = {"online",   "",   ""},   
    ["21630"] = {"internet",   "",   ""},   
    ["21670"] = {"internet.vodafone.net",   "",   ""},  
    
    --波黑
    ["21803"] = {"wap.eronet.ba",   "",   ""},   
    ["21805"] = {"3g1",   "",   ""},   
    ["21890"] = {"active.bhmobile.ba",   "",   ""},   
    
    --克罗地亚
    ["21901"] = {"web.htgprs",   "",   ""},   
    ["21910"] = {"data.vip.hr",   "38591",   "38591"},
    ["21902"] = {"internet.tele2.hr",   "",   ""},    
    
    --塞尔维亚
    ["22001"] = {"internet",   "telenor",   "gprs"},   
    ["22002"] = {"internet",   "gprs",   "gprs"},   
    ["22003"] = {"gprswap",   "mts",   "064"},   
    ["22004"] = {"tmcg-wnw",   "38267",   "38267"},   
    ["22005"] = {"vipmobile",   "vipmobile",   "vipmobile"},   
    
    --意大利
    ["22201"] = {"ibox.tim.it",   "",   ""},   
    ["22201"] = {"web.noverca.it",   "",   ""},   
    ["22210"] = {"mobile.vodafone.it",   "",   ""},   
    ["22210"] = {"web.omnitel.it",   "",   ""},   
    ["22288"] = {"internet.wind",   "",   ""},
    ["22299"] = {"apn.fastweb.it",   "",   ""},   
    ["22299"] = {"tre.it",   "",   ""},
    
    --罗马尼亚
    ["22601"] = {"internet.vodafone.ro",   "internet.vodafone.ro",   "vodafone"},   
    ["22601"] = {"live.vodafone.com",   "live",   "vodafone"},   
    ["22603"] = {"broadband",   "",   ""},   
    ["22603"] = {"wnw",   "wnw",   "wnw"},   
    ["22606"] = {"wnw",   "wnw",   "wnw"},   
    ["22610"] = {"internet",   "",   ""},   
    
    --瑞士
    ["22801"] = {"gprs.swisscom.ch",   "",   ""},   
    ["22802"] = {"internet",   "internet",   "internet"},   
    ["22803"] = {"internet",   "",   ""},   
    
    --捷克
    ["23001"] = {"internet.t-mobile.cz",   "wap",   "wap"},   
    ["23002"] = {"internet",   "",   ""},   
    ["23003"] = {"internet",   "",   ""},   
    ["23003"] = {"ointernet",   "",   ""},   
    
    --斯洛伐克
    ["23101"] = {"internet",   "",   ""},   
    ["23102"] = {"internet",   "",   ""},   
    ["23104"] = {"internet",   "",   ""},   
    ["23105"] = {"internet",   "",   ""},   
    ["23106"] = {"o2internet",   "",   ""},   
    
    --奥地利
    ["23201"] = {"a1.net",   "ppp@a1plus.at",   "ppp"},   
    ["23203"] = {"gprsinternet",   "t-mobile",   "tm"},   
    ["23205"] = {"orange.web",   "web",   "web"},   
    ["23207"] = {"web",   "web@telering.at",   "web"},   
    ["23211"] = {"bob.at",   "data@bob.at",   "ppp"},   
    ["23212"] = {"web.yesss.at",   "",   ""},
    ["23210"] = {"drei.at",   "",   ""}, 
    
    --丹麦
    ["23801"] = {"internet",   "",   ""},   
    ["23802"] = {"Internet",   "",   ""},   
    ["23820"] = {"www.internet.mtelia.dk",   "",   ""},   
    ["23877"] = {"Internet",   "",   ""},
    ["23806"] = {"data.tre.dk",   "",   ""},
    
    --瑞典
    ["24001"] = {"online.telia.se",   "",   ""},   
    ["24017"] = {"halebop.telia.se",   "",   ""},   
    ["24004"] = {"services.telenor.se",   "",   ""},   
    ["24006"] = {"services.telenor.se",   "",   ""},   
    ["24008"] = {"services.telenor.se",   "",   ""},   
    ["24009"] = {"services.telenor.se",   "",   ""},   
    ["24010"] = {"data.springmobil.se",   "",   ""},
    ["24002"] = {"data.tre.se",   "",   ""},   
    ["24007"] = {"internet.tele2.se",   "",   ""},    
    
    --挪威
    ["24201"] = {"telenor",   "",   ""},   
    ["24202"] = {"netcom",   "",   ""},   
    ["24204"] = {"internet.tele2.no",   "",   ""},   
    ["24205"] = {"internet",   "",   ""},   
    
    --芬兰
    ["24403"] = {"internet",   "",   ""},   
    ["24404"] = {"internet",   "",   ""},   
    ["24405"] = {"internet",   "",   ""},   
    ["24410"] = {"internet.song.fi",   "song@internet",   "songnet"},   
    ["24412"] = {"internet",   "",   ""},   
    ["24413"] = {"internet",   "",   ""},   
    ["24421"] = {"wap.saunalahti.fi",   "",   ""},   
    ["24491"] = {"internet",   "",   ""},   
    
    --立陶宛
    ["24601"] = {"omnitel",   "omni",   "omni"},   
    ["24602"] = {"banga",   "",   ""},   
    ["24603"] = {"internet.tele2.lt",   "",   ""},   
    
    --拉脱维亚
    ["24701"] = {"internet.lmt.lv",   "lmt",   "lmt"},   
    ["24702"] = {"internet.tele2.lv",   "wap",   "wap"},   
    ["24705"] = {"internet",   "",   ""},   
    
    --爱沙尼亚
    ["24801"] = {"internet.emt.ee",   "",   ""},   
    ["24802"] = {"internet",   "",   ""},   
    ["24803"] = {"internet.tele2.ee",   "",   ""},   
    
    --乌克兰
    ["25501"] = {"www.mts.ua",   "",   ""},   
    ["25502"] = {"internet.beeline.ua",   "",   ""},   
    ["25503"] = {"www.kyivstar.net",   "igprs",   "internet"},   
    ["25506"] = {"internet",   "",   ""},   
    
    --波兰
    ["26001"] = {"internet",   "",   ""},   
    ["26002"] = {"internet",   "",   ""},   
    ["26002"] = {"heyah.pl",   "",   ""},   
    ["26003"] = {"internet",   "internet",   "internet"},   
    ["26006"] = {"internet",   "",   ""},   
    
    --德国
    ["26202"] = {"web.vodafone.de",   "",   ""},   
    ["26203"] = {"internet.eplus.de",   "eplus",   "internet"},   
    ["26204"] = {"web.vodafone.de",   "",   ""},   
    ["26205"] = {"internet.eplus.de",   "eplus",   "internet"},   
    ["26209"] = {"web.vodafone.de",   "",   ""},   
    ["26201"] = {"internet.t-mobile",   "t-mobile",   "tm"},   
    ["26201"] = {"internet.telekom",   "telekom",   "telekom"},   
    ["26206"] = {"internet.t-mobile",   "t-mobile",   "tm"},   
    ["26207"] = {"internet",   "",   ""},   
    ["26207"] = {"pinternet.interkom.de",   "",   ""},   
    ["26208"] = {"internet",   "",   ""},   
    ["26211"] = {"internet",   "",   ""},
    
    --葡萄牙
    ["26801"] = {"net2.vodafone.pt",   "vodafone",   "vodafone"},   
    ["26806"] = {"internet",   "",   ""}, 
    ["26803"] = {"umts",   "",   ""},    
    
    --卢森堡
    ["27001"] = {"wap.pt.lu",   "wap",   "wap"},   
    ["27077"] = {"internet",   "tango",   "tango"},
    ["27099"] = {"vox.lu",   "",   ""},     
    
    --爱尔兰
    ["27201"] = {"live.vodafone.com",   "",   ""},   
    ["27203"] = {"data.mymeteor.ie",   "",   ""}, 
    ["27202"] = {"internet",   "",   ""},   
    ["27205"] = {"3ireland.ie",   "",   ""},   
    ["27211"] = {"tescomobile.liffeytelecom.com",   "",   ""},      
    
    --冰岛
    ["27401"] = {"internet",   "",   ""},   
    ["27402"] = {"gprs.is",   "",   ""},   
    ["27411"] = {"net.nova.is",   "",   ""},   
    
    --马耳他
    ["27801"] = {"internet",   "internet",   "internet"},   
    
    --塞浦路斯
    ["28010"] = {"wap",   "wap",   "wap"}, 
    ["28001"] = {"cytamobile",   "user",   "pass"},     
    
    --保加利亚
    ["28401"] = {"wap-gprs.mtel.bg",   "",   ""},   
    ["28403"] = {"wap.vivacom.bg",   "wap",   "wap"},   
    ["28405"] = {"globul",   "",   ""},   
    
    --土耳其
    ["28601"] = {"internet",   "",   ""},   
    ["28602"] = {"internet",   "vodafone",   "vodafone"},   
    ["28603"] = {"internet",   "",   ""},   
    
    --格陵兰岛
    ["29001"] = {"internet",   "",   ""},   
    
    --斯洛文尼亚
    ["29340"] = {"internet.simobil.si",   "simobil",   "internet"},   
    ["29341"] = {"internet",   "mobitel",   "internet"},   
    
    --马其顿王国
    ["29401"] = {"internet",   "internet",   "t-mobile"},   
    ["29402"] = {"Internet",   "Internet",   "Internet"},   
    ["29403"] = {"vipoperator",   "vipoperator",   "vipoperator"},   
    
    --黑山共和国
    ["29702"] = {"tmcg-wnw",   "38267",   "38267"},   
    
    --美国       
    ["310030"] = {"private.centennialwireless.com",   "privuser",   "priv"},   
    ["310090"] = {"isp",   "",   ""},   
    ["310100"] = {"plateauweb",   "",   ""},   
    ["310150"] = {"wap.cingular",   "",   ""},   
    ["310170"] = {"isp.cingular",   "",   ""},   
    ["310280"] = {"epc.tmobile.com",   "",   ""},   
    ["310280"] = {"internet2.voicestream.com",   "",   ""},   
    ["310280"] = {"wap.voicestream.com",   "",   ""},   
    ["310290"] = {"epc.tmobile.com",   "",   ""},   
    ["310290"] = {"internet2.voicestream.com",   "",   ""},   
    ["310290"] = {"wap.voicestream.com",   "",   ""},   
    ["310330"] = {"epc.tmobile.com",   "",   ""},   
    ["310330"] = {"internet2.voicestream.com",   "",   ""},   
    ["310330"] = {"wap.voicestream.com",   "",   ""},   
    ["310470"] = {"isp.cingular",   "",   ""},   
    ["310480"] = {"isp.cingular",   "",   ""},   
    ["310610"] = {"internet.epictouch",   "",   ""},   
    ["310770"] = {"i2.iwireless.com",   "",   ""},   
    ["310840"] = {"isp",   "",   ""},   
    ["311210"] = {"internet.farmerswireless.com",   "",   ""},
    ["310160"] = {"epc.tmobile.com",   "",   ""},   
    ["310200"] = {"epc.tmobile.com",   "",   ""},   
    ["310210"] = {"epc.tmobile.com",   "",   ""},   
    ["310220"] = {"epc.tmobile.com",   "",   ""},   
    ["310230"] = {"epc.tmobile.com",   "",   ""},   
    ["310240"] = {"epc.tmobile.com",   "",   ""},   
    ["310250"] = {"epc.tmobile.com",   "",   ""},   
    ["310260"] = {"fast.t-mobile.com",   "",   ""},   
    ["310260"] = {"epc.tmobile.com",   "",   ""},   
    ["310270"] = {"epc.tmobile.com",   "",   ""},   
    ["310310"] = {"epc.tmobile.com",   "",   ""},   
    ["310380"] = {"proxy",   "",   ""},   
    ["310410"] = {"wap.cingular",   "WAP@CINGULARGPRS.COM",   "CINGULAR1"},   
    ["310470"] = {"wap.cingular",   "WAP@CINGULARGPRS.COM",   "CINGULAR1"},   
    ["310480"] = {"wap.cingular",   "WAP@CINGULARGPRS.COM",   "CINGULAR1"},   
    ["310490"] = {"epc.tmobile.com",   "",   ""},   
    ["310580"] = {"epc.tmobile.com",   "",   ""},   
    ["310660"] = {"epc.tmobile.com",   "",   ""},   
    ["310800"] = {"epc.tmobile.com",   "",   ""},   
    ["310910"] = {"wap.firstcellular.com",   "",   ""},     
    
    --波多黎各
    ["330110"] = {"internet.claropr.com",   "",   ""},   
    
    --墨西哥
    ["334020"] = {"internet.itelcel.com",   "webgprs",   "webgprs2002"},   
    ["33402"] = {"internet.itelcel.com",   "webgprs",   "webgprs2002"},   
    ["334030"] = {"internet.movistar.mx",   "movistar",   "movistar"},   
    ["33403"] = {"internet.movistar.mx",   "movistar",   "movistar"},   
    ["334004"] = {"web.iusacellgsm.mx",   "iusacellgsm",   "iusacellgsm"},   
    ["334005"] = {"web.iusacellgsm.mx",   "iusacellgsm",   "iusacellgsm"},   
    ["334050"] = {"web.iusacellgsm.mx",   "iusacellgsm",   "iusacellgsm"},   
    
    --圣卢西亚岛
    ["338050"] = {"web",   "",   ""},   
    ["33818"] = {"internet",   "",   ""},   
    ["338070"] = {"internet.ideasclaro.com.jm",   "",   ""},   
    ["338180"] = {"internet",   "",   ""},   
    ["35811"] = {"internet",   "",   ""},   
    
    --法属安的列斯群岛
    ["34001"] = {"orangewap",   "orange",   "wap"}, 
    ["34020"] = {"wap.digicelfr.com",   "wap",   "wap"},     
    
    --巴巴多斯岛
    ["34260"] = {"internet",   "",   ""},   
    
    --安提瓜和巴布达
    ["34492"] = {"internet",   "",   ""},   
    
    --开曼群岛
    ["34614"] = {"internet",   "",   ""},   
    
    --英属维尔京群岛
    ["34817"] = {"internet",   "",   ""},   
    
    --格林纳达
    ["35211"] = {"internet",   "",   ""},   
    
    --蒙塞拉特岛
    ["35486"] = {"internet",   "",   ""},   
    
    --圣基茨和尼维斯联邦
    ["35611"] = {"internet",   "",   ""},   
    
    --圣文森特和格林纳丁斯    
    ["36011"] = {"internet",   "",   ""},   
    
    --阿鲁巴岛
    ["36302"] = {"web",   "",   ""},   
    ["363020"] = {"web",   "",   ""},   
    
    --安圭拉
    ["36584"] = {"internet",   "",   ""},   
    
    --多米尼克
    ["36611"] = {"internet",   "",   ""},   
    
    --古巴
    ["36801"] = {"internet",   "",   ""},   
    
    --多米尼加共和国
    ["37001"] = {"orangenet.com.do",   "",   ""},   
    ["37002"] = {"internet.ideasclaro.com.do",   "",   ""},   
    ["37004"] = {"edge.viva.net.do",   "viva",   "viva"},   
    
    --特立尼达和多巴哥
    ["37412"] = {"internet",   "",   ""},   
    ["374120"] = {"internet",   "",   ""},   
    ["374121"] = {"internet",   "",   ""},   
    ["374122"] = {"internet",   "",   ""},   
    ["374123"] = {"internet",   "",   ""},   
    ["374124"] = {"internet",   "",   ""},   
    ["374125"] = {"internet",   "",   ""},   
    ["374126"] = {"internet",   "",   ""},   
    ["374127"] = {"internet",   "",   ""},   
    ["374128"] = {"internet",   "",   ""},   
    ["374129"] = {"internet",   "",   ""},   
    ["37413"] = {"web.digiceltt.com",   "",   ""},   
    ["374130"] = {"web.digiceltt.com",   "",   ""},   
    
    --特克斯和凯科斯群岛
    ["37635"] = {"internet",   "",   ""},   
    
    --哈萨克斯坦
    ["40101"] = {"internet.beeline.kz",   "@internet.beeline",   "beeline"},   
    ["40102"] = {"internet",   "",   ""},   
    ["40177"] = {"internet",   "",   ""},   
    
    --巴基斯坦
    ["41001"] = {"connect.mobilinkworld.com",   "Mobilink",   "Mobilink"},   
    ["41003"] = {"Ufone.internet",   "",   ""},   
    ["41003"] = {"Ufone.pinternet",   "",   ""},   
    ["41004"] = {"zonginternet",   "",   ""},   
    ["41006"] = {"internet",   "",   ""},   
    ["41007"] = {"Wap.warid",   "",   ""},   
    ["410034"] = {"Ufone.internet",   "",   ""},   
    ["410034"] = {"Ufone.pinternet",   "",   ""},   
    
    --斯里兰卡
    ["41301"] = {"mobitel3g",   "",   ""},   
    ["41301"] = {"mobitel3g",   "",   ""},   
    ["41302"] = {"www.dialogsl.com",   "",   ""},   
    ["41303"] = {"internet",   "",   ""},   
    ["41305"] = {"AirtelLive",   "",   ""},   
    ["41305"] = {"airteldata",   "",   ""},   
    ["41308"] = {"htwap",   "",   ""},   
    
    --缅甸
    ["41401"] = {"mptnet",   "mptnet",   "mptnet"},   
    
    --黎巴嫩
    ["41501"] = {"internet.mic1.com.lb",   "mic1",   "mic1"},   
    ["41503"] = {"gprs.mtctouch.com.lb",   "",   ""},   
    
    --约旦
    ["41601"] = {"internet",   "",   ""},   
    ["41601"] = {"internetpre",   "zain",   "zain"},   
    ["41603"] = {"internet",   "",   ""},   
    ["41603"] = {"net",   "",   ""},   
    ["41677"] = {"net.orange.jo",   "net",   "net"},   
    
    --科威特
    ["41902"] = {"pps",   "pps",   "pps"},   
    ["41903"] = {"action.wataniya.com",   "",   ""},  
    ["41904"] = {"VIVA",   "",   ""},      
    
    --沙特阿拉伯
    ["42001"] = {"jawalnet.com.sa",   "",   ""},   
    ["42003"] = {"web2",   "",   ""},   
    ["42003"] = {"web1",   "",   ""},   
    ["42004"] = {"zain",   "",   ""},   
    
    --阿曼
    ["42202"] = {"taif",   "taif",   "taif"},   
    ["42203"] = {"isp.nawras.com.om",   "",   ""},   
    
    --阿拉伯
    ["42402"] = {"etisalat.ae",   "",   ""},   
    ["42403"] = {"du",   "",   ""},  
    
    --以色列
    ["42501"] = {"modem.orange.net.il",   "",   ""},   
    ["42502"] = {"Sphone",   "",   ""},   
    ["42503"] = {"sphone.pelephone.net.il",   "pcl@3g",   "pcl"}, 
    ["42501"] = {"uwap.orange.co.il",   "",   ""},     
    
    --巴林王国
    ["42601"] = {"internet.batelco.com",   "",   ""},   
    ["42602"] = {"internet",   "internet",   "internet"},   
    ["42604"] = {"viva.bh",   "",   ""},   
    
    --卡塔尔国
    ["42701"] = {"gprs.qtel",   "gprs",   "gprs"},   
    ["42702"] = {"web.vodafone.com.qa",   "",   ""},   
    
    --尼泊尔
    ["42901"] = {"ntnet",   "",   ""},   
    ["42902"] = {"web",   "",   ""},   
    
    --伊朗
    ["43211"] = {"mcinet",   "",   ""},   
    ["43220"] = {"RighTel",   "",   ""},   
    ["43235"] = {"mtnirancell",   "",   ""},   
    
    --中国香港     
    ["45400"] = {"internet",   "",   ""},   
    ["45402"] = {"internet",   "",   ""},   
    ["45403"] = {"mobile.three.com.hk",   "",   ""},   
    ["45404"] = {"web-g.three.com.hk",   "",   ""},   
    ["45406"] = {"internet",   "",   ""},   
    ["45407"] = {"3gwap",   "",   ""},   
    ["45410"] = {"internet",   "",   ""},   
    ["45412"] = {"CMHK Data",   "",   ""},   
    ["45414"] = {"web-g.three.com.hk",   "",   ""},   
    ["45416"] = {"pccwdata",   "",   ""},   
    ["45418"] = {"internet",   "",   ""}, 
    ["45400"] = {"hkcsl",   "",   ""},   
    ["45402"] = {"hkcsl",   "",   ""},   
    ["45403"] = {"mobile.three.com.hk",   "",   ""},   
    ["45410"] = {"hkcsl",   "",   ""},   
    ["45415"] = {"SmarTone",   "",   ""},   
    ["45417"] = {"SmarTone",   "",   ""},   
    ["45418"] = {"hkcsl",   "",   ""},   
    ["45419"] = {"pccw",   "",   ""},  
    ["45400"] = {"cmwap",   "",   ""},   
    ["45407"] = {"cmwap",   "",   ""},     
    
    --中国澳门
    ["45501"] = {"ctm-mobile",   "",   ""},   
    ["45501"] = {"ctmprepaid",   "",   ""},   
    ["45503"] = {"web-g.three.com.hk",   "hutchison",   "1234"},   
    ["45504"] = {"ctm-mobile",   "",   ""},   
    ["45500"] = {"smartgprs",   "",   ""},  
    
    --柬埔寨
    ["45601"] = {"cellcard",   "mobitel",   "mobitel"},   
    ["45601"] = {"postpaid",   "mobitel",   "mobitel"},   
    ["45602"] = {"hellowww",   "",   ""},   
    ["45604"] = {"wap",   "",   ""},   
    ["45605"] = {"internet",   "",   ""},   
    ["45606"] = {"smart ",   "",   ""},   
    ["45606"] = {"smart ",   "",   ""},   
    ["45608"] = {"metfone",   "",   ""},   
    ["45609"] = {"gprs.beeline.com.kh",   "",   ""},   
    ["45618"] = {"mfone",   "",   ""},   
    ["45618"] = {"mfone",   "",   ""},   
    
    --中国台湾
    ["46601"] = {"internet",   "",   ""},   
    ["46601"] = {"internet",   "",   ""},   
    ["46688"] = {"internet",   "",   ""},   
    ["46689"] = {"auroraweb",   "",   ""},   
    ["46689"] = {"viboone",   "",   ""},   
    ["46689"] = {"vibo",   "",   ""},   
    ["46692"] = {"internet",   "",   ""},   
    ["46693"] = {"internet",   "",   ""},   
    ["46693"] = {"twm",   "",   ""},   
    ["46697"] = {"internet",   "",   ""},   
    ["46697"] = {"twm",   "",   ""},   
    ["46699"] = {"internet",   "",   ""},   
    ["46699"] = {"twm",   "",   ""}, 
    ["46689"] = {"vibo",   "",   ""},   
    ["46692"] = {"emome",   "",   ""},     
    
    --孟加拉共和国
    ["47001"] = {"gpinternet",   "",   ""},   
    ["47002"] = {"internet",   "",   ""},   
    ["47003"] = {"blweb",   "",   ""},   
    ["47006"] = {"internet",   "",   ""},   
    ["47007"] = {"internet",   "",   ""},   
    
    --马来西亚
    ["50212"] = {"net",   "maxis",   "wap"},   
    ["50212"] = {"unet",   "maxis",   "wap"},   
    ["50213"] = {"celcom3g",   "",   ""},   
    ["50213"] = {"celcom",   "",   ""},   
    ["50216"] = {"diginet",   "digi",   "digi"},   
    ["50218"] = {"my3g",   "",   ""},   
    ["50219"] = {"celcom.net.my",   "",   ""},   
    ["50219"] = {"celcom",   "",   ""},   
    
    --诺福克岛
    ["50501"] = {"Telstra.wap",   "",   ""},   
    ["50502"] = {"internet",   "",   ""},   
    ["50502"] = {"yesinternet",   "",   ""},   
    ["50503"] = {"vfinternet.au",   "",   ""},   
    ["50506"] = {"3netaccess",   "",   ""},   
    ["50507"] = {"vfinternet.au",   "",   ""},   
    ["50511"] = {"Telstra.wap",   "",   ""},   
    ["50512"] = {"3netaccess",   "",   ""},   
    ["50571"] = {"Telstra.wap",   "",   ""},   
    ["50572"] = {"Telstra.wap",   "",   ""},   
    ["50588"] = {"vfinternet.au",   "",   ""},
    ["50590"] = {"internet",   "",   ""}, 
    ["50506"] = {"3services",   "",   ""},   
    ["50512"] = {"3services",   "",   ""},    
    
    --菲律宾
    ["51502"] = {"http.globe.com.ph",   "",   ""},   
    ["51502"] = {"www.globe.com.ph",   "",   ""},   
    ["51502"] = {"internet.globe.com.ph",   "",   ""},   
    ["51503"] = {"internet",   "",   ""},   
    ["51505"] = {"minternet",   "",   ""},   
    ["51505"] = {"wap",   "",   ""},   
    ["51518"] = {"redinternet",   "",   ""},   
    
    --泰国
    ["52000"] = {"internet",   "",   ""},   
    ["52001"] = {"internet",   "",   ""},   
    ["52003"] = {" internet",   "",   ""},   
    ["52004"] = {"internet",   "",   ""},   
    ["52005"] = {"www.dtac.co.th",   "",   ""},   
    ["52015"] = {"internet",   "",   ""},   
    ["52018"] = {"www.dtac.co.th",   "",   ""},   
    ["52023"] = {"internet",   "",   ""},   
    ["52099"] = {"internet",   "",   ""},   
    ["52501"] = {"hicard",   "65IDEAS",   "IDEAS"},   
    
    --新西兰
    ["53001"] = {"www.vodafone.net.nz",   "",   ""},   
    ["53002"] = {"www.vodafone.net.nz",   "",   ""},   
    ["53005"] = {"internet.telecom.co.nz",   "",   ""},   
    ["53024"] = {"internet",   "",   ""},   
    
    --埃及
    ["60201"] = {"mobinilweb",   "",   ""},   
    ["60202"] = {"internet.vodafone.net",   "internet",   "internet"},   
    ["60203"] = {"etisalat",   "",   ""},   
    
    --摩洛哥
    ["60400"] = {"internet1.meditel.ma",   "MEDINET",   "MEDINET"},   
    ["60405"] = {"www.iamgprs1.ma",   "",   ""},   
    
    --突尼斯
    ["60501"] = {"weborange",   "",   ""},   
    ["60502"] = {"gprs.tn",   "gprs",   "gprs"},   
    ["60503"] = {"internet.tunisiana.com",   "internet",   "internet"},   
    
    --马里共和国
    ["61001"] = {"web.malitel3.ml",   "internet",   "internet"},   
    ["61002"] = {"internet",   "",   ""},   
    
    --加纳共和国
    ["62001"] = {"internet",   "",   ""},   
    ["62002"] = {"browse",   "",   ""},   
    ["62003"] = {"web.tigo.com.gh",   "",   ""},   
    ["62006"] = {"internet",   "",   ""},   
    ["62007"] = {"internet",   "",   ""},   
    ["62007"] = {"glowap",   "glo",   "glo"},   
    
    --尼日利亚
    ["62120"] = {"internet.ng.airtel.com",   "internet",   "internet"},   
    ["62130"] = {"web.gprs.mtnnigeria.net",   "web",   "web"},   
    ["62150"] = {"glosecure",   "gprs",   "gprs"},   
    ["62160"] = {"etisalat",   "",   ""},   
    
    --喀麦隆
    ["62401"] = {"mtnwap",   "mtnuser",   "mtnuser"},   
    ["62402"] = {"orangecmgprs",   "orange",   "orange"},   
    
    --苏丹
    ["63401"] = {"internet",   "",   ""},   
    ["63402"] = {"Internet",   "",   ""},   
    ["63402"] = {"wap",   "",   ""},   
    ["63407"] = {"sudaninet",   "sudani",   "sudani"},   
    ["63407"] = {"sudaniwap",   "sudani",   "sudani"},   
    
    --埃塞俄比亚
    ["63601"] = {"etc.com",   "",   ""},   
    
    --肯尼亚
    ["63907"] = {"wap.orange.co.ke",   "",   ""},   
    ["63902"] = {"Safaricom",   "saf",   "data"},   
    ["63905"] = {"internet",   "",   ""},   
    ["63905"] = {"internet",   "",   ""},   
    ["63903"] = {"ke.celtel.com",   "internet",   ""},   
    ["63903"] = {"wap",   "",   ""},   
    ["63903"] = {"internet",   "",   ""},   
    ["63907"] = {"bew.orange.co.ke",   "",   ""},   
    
    --坦桑尼亚
    ["64002"] = {"internet",   "",   ""},   
    ["64003"] = {"internet",   "",   ""},   
    ["64004"] = {"internet",   "",   ""},   
    ["64005"] = {"internet",   "",   ""},   
    
    --乌干达
    ["64101"] = {"web.ug.zain.com",   "",   ""},   
    ["64110"] = {"yellopix.mtn.co.ug",   "",   ""},   
    ["64111"] = {"utweb",   "",   ""},   
    ["64114"] = {"orange.ug",   "",   ""},   
    ["64122"] = {"web.waridtel.co.ug",   "",   ""},   
    
    --莫桑比克
    ["64301"] = {"isp.mcel.mz",   "",   ""},   
    ["64304"] = {"internet",   "",   ""},   
    
    --马达加斯加岛
    ["64601"] = {"internet.mg.airtel.com",   "",   ""},   
    ["64602"] = {"orangenet",   "",   ""},   
    ["64604"] = {"internet",   "",   ""},   
    
    --法属印度洋领地
    ["64700"] = {"orangerun",   "orange",   "orange"},   
    ["64710"] = {"wapsfr",   "wap",   "wap"},   
    
    --津巴布韦
    ["64804"] = {"econet.net",   "",   ""},   
    ["64803"] = {"internet",   "",   ""},   
    
    --莱索托
    ["65101"] = {"internet",   "",   ""},   
    
    --南非
    ["65501"] = {"internet",   "",   ""},   
    ["65502"] = {"internet",   "",   ""},   
    ["65507"] = {"Internet",   "",   ""},   
    ["65507"] = {"vdata",   "",   ""},   
    ["65510"] = {"internet",   "",   ""},   
    
    --危地马拉
    ["70401"] = {"internet.ideasclaro",   "",   ""},   
    ["70402"] = {"broadband.tigo.gt",   "",   ""},   
    ["70403"] = {"internet.movistar.gt",   "movistargt",   "movistargt"},   
    ["704030"] = {"internet.movistar.gt",   "movistargt",   "movistargt"},   
    
    --萨尔瓦多
    ["70601"] = {"internet.ideasclaro",   "",   ""},   
    ["70602"] = {"web.digicelsv.com",   "",   ""},   
    ["70603"] = {"internet.tigo.sv",   "",   ""},   
    ["70604"] = {"internet.movistar.sv",   "movistarsv",   "movistarsv"},   
    ["70611"] = {"internet.ideasclaro",   "",   ""},   
    ["706040"] = {"internet.movistar.sv",   "movistarsv",   "movistarsv"},   
    
    --洪都拉斯
    ["70801"] = {"wap.megatel.hn",   "",   ""},   
    ["70802"] = {"internet.tigo.hn",   "",   ""},   
    ["70802"] = {"internet.tigo.hn",   "",   ""},   
    ["708001"] = {"web.megatel.hn",   "webmegatel",   "webmegatel"},   
    ["708020"] = {"internet.tigo.hn",   "",   ""},   
    ["70840"] = {"wap.digicelhn.com",   "",   ""},   
    ["70840"] = {"web.digicelhn.com",   "",   ""},   
    
    --尼加拉瓜
    ["71021"] = {"web.emovil",   "webemovil",   "webemovil"},   
    ["710300"] = {"internet.movistar.ni",   "movistarni",   "movistarni"},   
    ["710730"] = {"web.emovil",   "webemovil",   "webemovil"},   
    
    --哥斯达黎加
    ["71203"] = {"internet.ideasclaro",   "",   ""},   
    ["71204"] = {"internet.movistar.cr",   "movistarcr",   "movistarcr"}, 
    ["71201"] = {"kolbi3g",   "",   ""},    
    
    --巴拿马
    ["71401"] = {"apn01.cwpanama.com.pa",   "",   ""},   
    ["71402"] = {"wap.movistar.pa",   "movistarpawap",   "movistarpa"},   
    ["71403"] = {"web.claro.com.pa",   "CLAROWEB",   "CLAROWEB"},   
    ["71404"] = {"web.digicelpanama.com",   "",   ""},   
    ["714020"] = {"internet.movistar.pa",   "movistarpa",   "movistarpa"},   
    
    --秘鲁
    ["71606"] = {"movistar.pe",   "movistar@datos",   "movistar"},   
    ["71610"] = {"claro.pe",   "claro",   "claro"},   
    ["71617"] = {"wap.nextel.com.pe",   "",   ""},   
    
    --阿根廷
    ["72207"] = {"wap.gprs.unifon.com.ar",   "wap",   "wap"},   
    ["72210"] = {"wap.gprs.unifon.com.ar",   "wap",   "wap"},   
    ["72231"] = {"igprs.claro.com.ar",   "ctigprs",   "ctigprs999"},   
    ["72234"] = {"datos.personal.com",   "datos",   "datos"},   
    ["72236"] = {"gprs.personal.com",   "gprs",   "adgj"},   
    ["72270"] = {"wap.gprs.unifon.com.ar",   "wap",   "wap"},   
    ["722310"] = {"igprs.claro.com.ar",   "ctigprs",   "ctigprs999"},   
    ["722320"] = {"wap.ctimovil.com.ar",   "ctigprs",   "ctigprs999"},   
    ["722330"] = {"wap.ctimovil.com.ar",   "ctigprs",   "ctigprs999"},   
    ["722341"] = {"datos.personal.com",   "datos",   "datos"},   
    
    --巴西
    ["72402"] = {"timbrasil.br",   "tim",   "tim"},   
    ["72403"] = {"timbrasil.br",   "tim",   "tim"},   
    ["72404"] = {"timbrasil.br",   "tim",   "tim"},   
    ["72405"] = {"claro.com.br",   "",   ""},   
    ["72405"] = {"wap.claro.com.br",   "claro",   "claro"},   
    ["72406"] = {"zap.vivo.com.br",   "vivo",   "vivo"},   
    ["72407"] = {"sercomtel.com.br",   "sercomtel",   "sercomtel"},   
    ["72410"] = {"zap.vivo.com.br",   "vivo",   "vivo"},   
    ["72411"] = {"zap.vivo.com.br",   "vivo",   "vivo"},   
    ["72416"] = {"gprs.oi.com.br",   "",   ""},   
    ["72419"] = {"gprs.telemigcelular.com.br",   "celular",   "celular"},   
    ["72423"] = {"zap.vivo.com.br",   "vivo",   "vivo"},   
    ["72424"] = {"gprs.oi.com.br",   "",   ""},   
    ["72431"] = {"gprs.oi.com.br",   "",   ""},   
    ["72439"] = {"wap.nextel3g.net.br",   "",   ""},   
    
    --委内瑞拉
    ["73401"] = {"gprsweb.digitel.ve",   "",   ""},   
    ["73402"] = {"gprsweb.digitel.ve",   "",   ""},   
    ["73403"] = {"gprsweb.digitel.ve",   "",   ""},   
    ["73404"] = {"internet.movistar.ve",   "",   ""},   
    ["73406"] = {"int.movilnet.com.ve",   "",   ""},   
    
    --玻利维亚
    ["73601"] = {"internet.nuevatel.com",   "",   ""},   
    ["73602"] = {"int.movil.com.bo",   "",   ""},   
    ["73603"] = {"wap.tigo.bo",   "",   ""},   
    
    --厄瓜多尔
    ["74000"] = {"internet.movistar.com.ec",   "movistar",   "movistar"},   
    ["74001"] = {"internet.claro.com.ec",   "",   ""},   
    ["74002"] = {"internet3gsp.alegro.net.ec",   "",   ""},   
    ["740010"] = {"internet.claro.com.ec",   "",   ""},   
    
    --巴拉圭
    ["74401"] = {"vox.internet",   "",   ""},   
    ["74402"] = {"internet.ctimovil.com.py",   "",   ""},   
    ["74404"] = {"internet.tigo.py",   "",   ""},   
    ["74405"] = {"internet",   "",   ""},   
    ["74405"] = {"internet",   "personal",   "personal"},   
    
    --乌拉圭
    ["74801"] = {"gprs.ancel",   "",   ""},   
    ["74807"] = {"webapn.movistar.com.uy",   "movistar",   "movistar"},   
    ["74810"] = {"igprs.claro.com.uy",   "ctigprs",   "ctigprs999"},   
    
    --日本    
    ["44000"] = {"em.lite",   "em",   "em"},
    ["44010"] = {"mopera.net",   "",   ""},   
    ["44010"] = {"mopera.flat.foma.ne.jp",   "",   ""},   
    ["44010"] = {"bmobile.ne.jp",   "bmobile@spd",   "bmobile"},   
    ["44010"] = {"dm.jplat.net",   "bmobile@cm",   "bmobile"},   
    ["44010"] = {"dm.jplat.net",   "bmobile@aeon",   "bmobile"},   
    ["44010"] = {"bmobile.ne.jp",   "bmobile@fr",   "bmobile"},   
    ["44010"] = {"dm.jplat.net",   "dm.jplat.net",   "bmobile"},   
    ["44010"] = {"iijmio.jp",   "mio@iij",   "iij"},   
    ["44010"] = {"biglobe.jp",   "user",   "0000"},   
    ["44010"] = {"vmobile.jp ",   "lte@hi-ho",   "hi-ho"},   
    ["44010"] = {"so-net.jp",   "nuro",   "nuro"},   
    ["44010"] = {"lte-d.ocn.ne.jp",   "",   ""},   
    ["44010"] = {"vmobile.jp",   "bb@excite.co.jp",   "excite"},   
    ["44010"] = {"dream.jp",   "user@dream.jp",   "dti"},   
    ["44010"] = {"umobile.jp",   "umobile@umobile.jp",   "umobile"},   
    ["44020"] = {"open.softbank.ne.jp",   "opensoftbank",   "ebMNuX1FIHg9d3DA"},   
    ["44020"] = {"smile.world",   "dna1trop",   "so2t3k3m2a"}, 
}


-- SIM卡 IMSI READY以后自动设置APN
sys.subscribe("IMSI_READY", 
    function()
        local code = (sim.getImsi()):sub(1,6)
        if apnTable[code] then
            link.setAPN(unpack(apnTable[code]))
        elseif apnTable[code:sub(1,5)] then
            link.setAPN(unpack(apnTable[code:sub(1,5)]))
        else
            --根据实际情况设置默认值
            --link.setAPN()
        end
    end
)


