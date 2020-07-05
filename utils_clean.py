import json
import pandas as pd
import re
import csv
from datetime import datetime
from dateutil import parser


def check_answer(clean_remarks, spox, ch=True):
    if ch:
        answer_a = bool(re.match("^答：", clean_remarks))
        answer_name = bool(re.match(("^" + spox + "："), clean_remarks))
    else:
        answer_a = bool(re.match("^A:", clean_remarks))
        answer_name = bool(re.match(("^" + spox + ":"), clean_remarks))
    return(answer_a or answer_name)



def check_qa(clean_remarks, ch=True):
    if ch:
        foundmatch = re.match("^[\\u4e00-\\u9fff]{1,15}：", clean_remarks)
    else:
        foundmatch = re.match("^[A-Za-z ]{1,30}:", clean_remarks)
    return(bool(foundmatch))


def get_clean_remarks(remarks):
    question_flag = "</b>" in remarks.lower() or "</strong>" in remarks.lower()
    clean = re.sub('&nbsp;', ' ', remarks)  # space
    clean = re.sub('\\xa0', ' ', clean)     # space
    clean = re.sub('\\u3000', '', clean)    # ideographic space; make empty
    clean = re.sub('(?<=<).*?(?=>)', '', clean)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean, question_flag)


def get_clean_type(scraped_entry, ch=True):
    titleraw = scraped_entry['title'][0]

    clean_type = "No Type"
    if ch:
        if '例行记者会' in titleraw:
            clean_type = "Regular Press Conference"
        elif '谈话' in titleraw:
            clean_type = "Remarks"
    else:
        if "Regular Press Conference" in titleraw:
            clean_type = "Regular Press Conference"
        elif "Remarks" in titleraw:
            clean_type = "Remarks"
    return(clean_type)


def get_clean_date(scraped_entry, ch=True):
    titleraw = scraped_entry['title'][0]
    dateraw = scraped_entry['date'][0]

    if ch:
        return(dateraw)
    else:
        datestring = re.findall("(?<= on )(.*)(?=)", titleraw)
        clean_date = None
        if len(datestring) > 0:
            if "20" in datestring[0]:
                clean_date = datestring[0]
                clean_date = parser.parse(clean_date).strftime("%Y-%m-%d")
        return(clean_date)



def get_clean_spox(scraped_entry, ch=True):
    titleraw = scraped_entry['title'][0]
    textinitialraw = scraped_entry['text'][0]
    if len(scraped_entry['text']) > 1:
        textinitialraw = textinitialraw + scraped_entry['text'][1]

    # lookup dictionary for chinese foreign ministry spox
    spox_lookup = {
        ('Zhao Lijian', '赵立坚'): 'ZHAO Lijian|赵立坚',
        ('Lu Kang', '陆慷'): 'LU Kang|陆慷',
        ('Hua Chunying', '华春莹'): 'HUA Chunying|华春莹',
        ('Geng Shuang', '耿爽'): 'GENG Shuang|耿爽'
    }

    index = 1 if ch else 0
    # spox = re.findall("(?<=^Foreign Ministry Spokesperson )(.+?)(?=')", titleraw)[0]
    outspox = "None"
    outspox_orig = "None"
    for key, value in spox_lookup.items():
        spoxfind = key[index]
        if spoxfind in titleraw:
            outspox = value
            outspox_orig = spoxfind
            break
    # if don't find spox in title, check first two lines of content for name
    if outspox == "None" and ch:
        for key, value in spox_lookup.items():
            spoxfind = key[index]
            if spoxfind in textinitialraw:
                outspox = value
                outspox_orig = spoxfind
                break
    return(outspox_orig, outspox)
