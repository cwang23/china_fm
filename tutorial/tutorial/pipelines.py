# -*- coding: utf-8 -*-
from scrapy.exporters import CsvItemExporter, JsonItemExporter

# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html


class TutorialPipeline:
    def process_item(self, item, spider):
        return item

# http://scrapingauthority.com/2016/09/19/scrapy-exporting-json-and-csv/
class CsvPipeline(object):
    def __init__(self):
        self.file = open("mf_press.csv", 'wb')
        self.exporter = CsvItemExporter(self.file)
        self.exporter.start_exporting()

    def close_spider(self, spider):
        self.exporter.finish_exporting()
        self.file.close()

    def process_item(self, item, spider):
        self.exporter.export_item(item)
        return item


class JsonPipeline(object):
    def __init__(self):
        self.file = open("mf_press.json", 'wb')
        self.exporter = JsonItemExporter(self.file, encoding='utf-8', ensure_ascii=False)
        self.exporter.start_exporting()

    def close_spider(self, spider):
        self.exporter.finish_exporting()
        self.file.close()

    def process_item(self, item, spider):
        self.exporter.export_item(item)
        return item
