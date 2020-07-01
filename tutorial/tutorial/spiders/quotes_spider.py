import scrapy
from scrapy import Request


class QuotesSpider(scrapy.Spider):
    name = "quotes"
    start_urls = [
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_1.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_2.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_3.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_4.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_5.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_6.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_7.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_8.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_9.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_10.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_11.shtml",
        "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403/default_12.shtml"
    ]

    def parse(self, response):
        xp = '//*[contains(concat( " ", @class, " " ), concat( " ", "fl", " " ))]//a/@href'
        urls = response.xpath(xp).extract()

        rooturl = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403"
        parseurls = []
        for u in urls:
            if "shtml" in u:
                out = rooturl + u.replace(".", "", 1)
                parseurls.append(out)
        return(Request(suburl, callback=self.parse_mf_press) for suburl in parseurls)

        # nextpage_links = response.xpath('//*[(@id = "pages")]').get()
        # next_page = response.xpath('//*[(@id = "id_RelNewsList")]//a/@href').get()
        # if next_page is not None:
        #     yield response.follow(next_page, callback=self.parse)

    def parse_mf_press(self, response):
        yield {
            'title': response.xpath('//title/text()').getall(),
            'text': response.xpath('//p').getall()
        }
