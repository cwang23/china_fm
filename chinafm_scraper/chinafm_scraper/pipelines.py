# -*- coding: utf-8 -*-
from scrapy.exporters import CsvItemExporter, JsonItemExporter
from datetime import datetime
# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html

# http://scrapingauthority.com/2016/09/19/scrapy-exporting-json-and-csv/
class JsonPipeline(object):
    def __init__(self):
        filename = "chinamf_press_" + datetime.today().strftime("%Y%m%d") + ".json"
        self.file = open(filename, 'wb')
        self.exporter = JsonItemExporter(self.file, encoding='utf-8', ensure_ascii=False)
        self.exporter.start_exporting()

    def close_spider(self, spider):
        self.exporter.finish_exporting()
        self.file.close()

    def process_item(self, item, spider):
        self.exporter.export_item(item)
        return item
