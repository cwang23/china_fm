# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://docs.scrapy.org/en/latest/topics/items.html
import scrapy

class ChinaFmScraperItem(scrapy.Item):
    title = scrapy.Field()
    text = scrapy.Field()
    date = scrapy.Field()
    url = scrapy.Field()
    lang = scrapy.Field()
    scrape_date = scrapy.Field()
