import json
import pandas as pd
import re
import csv
from dateutil import parser
from datetime import datetime
from utils_clean import *


## READ IN SCRAPED FILE --------------------------------------------------------
fname = "C:/Users/clara/Documents/china_fm/chinafm_scraper/rawdata/chinafm_press_" + datetime.today().strftime("%Y%m%d") + ".json"
fname
#fname = "C:/Users/clara/Documents/china_fm/chinafm_scraper/rawdata/chinafm_press_20200704.json"

with open(fname, 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")

len(data)


## PARSE SCRAPED DATA ----------------------------------------------------------
# initialize empty lists to store clean output
clean_output_ch = list()
clean_output_en = list()

for entry in data:
    text = entry['text']
    clean_lang = entry['lang']
    clean_scrape_date = datetime.strptime(entry['scrape_date'], "%Y%m%d").strftime("%Y-%m-%d")
    clean_url = entry['url']

    # flag for whether it's in Chinese
    is_ch = clean_lang == "Chinese"

    # clean title and date information
    orig_spox, clean_spox = get_clean_spox(entry, is_ch)
    clean_date = get_clean_date(entry, is_ch)
    clean_remarkstype = get_clean_type(entry, is_ch)

    # initialize empty lists to store cleaned lines information
    clean_remarks = []
    clean_order = []
    clean_contenttype = []
    clean_string = ''
    order_start = 1

    # iterate through each line and parse
    for line in text:
        stripped_text, question_flag = get_clean_remarks(line)

        # only parse the line if it's not empty
        if stripped_text.strip() != "":

            # check if it's a question or answer block
            q_or_a = check_qa(stripped_text, is_ch) or question_flag
            answer_flag = check_answer(stripped_text, orig_spox, is_ch)

            if answer_flag:
                blocktype = "A"
            elif question_flag:
                blocktype = "Q"
            else:
                blocktype = "None"

            # if just beginning, set cleaned string as start
            if clean_string == '':
                clean_string = stripped_text
                clean_type = blocktype

            # if it's a question or answer, set the start of new clean string
            # to this beginning question or answer
            elif q_or_a:
                # add the current info to list
                clean_remarks.append(clean_string)
                clean_order.append(order_start)
                clean_contenttype.append(clean_type)

                # reset values to signal start of answer or question
                order_start += 1
                clean_string = stripped_text
                clean_type = blocktype

            # if it's not the beginning of a section, add it to the string
            else:
                clean_string = clean_string + '<br><br>' + stripped_text

    # add the last paragraph to the lists
    clean_remarks.append(clean_string)
    clean_order.append(order_start)
    clean_contenttype.append(clean_type)

    # make dictionary to store cleaned info
    out = {
        "title": entry['title'][0],
        "spox": clean_spox,
        "date": clean_date,
        "type": clean_remarkstype,
        "content": clean_remarks,
        "content_order": clean_order,
        "content_type": clean_contenttype,
        'url': clean_url,
        'lang': clean_lang,
        'scrape_date': clean_scrape_date
    }

    if is_ch:
        clean_output_ch.append(out)
    else:
        clean_output_en.append(out)


## STACK AND WRITE DATA --------------------------------------------------------
# make it a data frame
full_clean_en = pd.DataFrame(clean_output_en)
full_clean_en.shape
full_clean_ch = pd.DataFrame(clean_output_ch)
full_clean_ch.shape


# identify index columns
index_cols = ['title', 'date', 'spox', 'type', 'url', 'lang', 'scrape_date']
# explode into rows
expanded_full_clean_en = full_clean_en.set_index(index_cols).apply(pd.Series.explode).reset_index()
expanded_full_clean_en.shape
expanded_full_clean_ch = full_clean_ch.set_index(index_cols).apply(pd.Series.explode).reset_index()
expanded_full_clean_ch.shape

# read in original files
original_en = pd.read_csv('C:/Users/clara/Documents/china_fm/chinafm_app/clean_fm_en.csv', encoding='utf-8', index_col=0)
original_en.shape
original_ch = pd.read_csv('C:/Users/clara/Documents/china_fm/chinafm_app/clean_fm_ch.csv', encoding='utf-8', index_col=0)
original_ch.shape

# stack dataframes
stacked_en = pd.concat([original_en, expanded_full_clean_en])
stacked_en.shape
stacked_ch = pd.concat([original_ch, expanded_full_clean_ch])
stacked_ch.shape

stacked_en = stacked_en.drop(columns=['scrape_date'])
stacked_ch = stacked_ch.drop(columns=['scrape_date'])

# remove duplicates
stacked_en.drop_duplicates(subset=list(stacked_en), keep='first', inplace=True)
stacked_en.shape
stacked_ch.drop_duplicates(subset=list(stacked_ch), keep='first', inplace=True)
stacked_ch.shape

# write to csv
stacked_en.to_csv("C:/Users/clara/Documents/china_fm/chinafm_app/clean_fm_en.csv")
stacked_ch.to_csv("C:/Users/clara/Documents/china_fm/chinafm_app/clean_fm_ch.csv")
