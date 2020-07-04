# -*- coding: utf-8 -*-
import scrapy
from scrapy import Request
from datetime import datetime
from ..items import ChinaFmScraperItem


en_root = "https://www.fmprc.gov.cn/mfa_eng/xwfw_665399/s2510_665401/2511_665403"
en_urls = [en_root + "/default.shtml"]
en_urls.extend([en_root + "/default_{:d}".format(x) + ".shtml" for x in range(1, 13)])

ch_root = "https://www.fmprc.gov.cn/web/wjdt_674879/fyrbt_674889"
ch_urls = [ch_root + "/default.shtml"]
ch_urls.extend([ch_root + "/default_{:d}".format(x) + ".shtml" for x in range(1, 67)])


class ChinaFmSpider(scrapy.Spider):
    name = 'chinafm'

    start_urls = en_urls + ch_urls

    def parse(self, response):
        # is it a url for a chinese site
        is_ch_url = True if (ch_root in response.url) else False
        self.logger.info('Parse function called on %s', response.url)
        self.logger.info('URL identified as Chinese: %s', str(is_ch_url))

        ch_xp = '//*[contains(concat( " ", @class, " " ), concat( " ", "rebox_news", " " ))]//a/@href'
        en_xp = '//*[contains(concat( " ", @class, " " ), concat( " ", "fl", " " ))]//a/@href'

        urls = response.xpath(ch_xp).extract() if is_ch_url else response.xpath(en_xp).extract()
        rooturl = ch_root if is_ch_url else en_root

        parseurls = []
        for u in urls:
            if "shtml" in u:
                out = rooturl + u.replace(".", "", 1)
                parseurls.append(out)
        return(Request(suburl, callback=self.parse_mf_press, meta={'is_ch_url': is_ch_url}) for suburl in parseurls)

    def parse_mf_press(self, response):
        is_ch_url = response.meta['is_ch_url']

        if is_ch_url:
            title = response.xpath('//*[(@id = "News_Body_Title")]').getall()
            date = response.xpath('//*[(@id = "News_Body_Time")]').getall()
            text = response.xpath('//p').getall()
        else:
            title = response.xpath('//title/text()').getall()
            date = "None"
            text = response.xpath('//p').getall()


        items = ChinaFmScraperItem()

        items['title'] = title
        items['date'] = date
        items['text'] = text
        items['url'] = response.url
        items['lang'] = 'Chinese' if is_ch_url else 'English'
        items['scrape_date'] = datetime.today().strftime("%Y%m%d")

        yield items
