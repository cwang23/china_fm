import json
import pandas as pd
import re
import csv
from datetime import datetime


# read in scraped data
fname = "C:/Users/clara/Documents/china_fm/chinafm_scraper/chinamf_press_" + datetime.today().strftime("%Y%m%d") + ".json"
fname = "C:/Users/clara/Documents/china_fm/chinafm_scraper/chinamf_press_" + "20200703" + ".json"

with open(fname, 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")

len(data)

data[1499]

def clean_html_tags(remarks):
    question_flag = "</b>" in remarks.lower() or "</strong>" in remarks.lower()
    clean = re.sub('&nbsp;', ' ', remarks)  # space
    clean = re.sub('\\xa0', ' ', clean)     # space
    clean = re.sub('\\u3000', '', clean)    # ideographic space; make empty
    clean = re.sub('(?<=<).*?(?=>)', '', clean)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean, question_flag)

# initialize empty list to store clean output
clean_output = list()

for i in range(0, len(data)):
    # print(i)
    entry = data[i]
    title = entry['title'][0]
    line = entry['text']
    clean_url = entry['url']
ls

    # clean title information
    clean_spox = re.findall("(?<=^Foreign Ministry Spokesperson )(.+?)(?=')", title)[0]
    topicdate = re.findall("(?<= on )(.*)(?=)", title)

    clean_date = "No Date"
    clean_topic = "No Topic"
    if len(topicdate) > 0:
        if "20" in topicdate[0]:
            clean_date = topicdate[0]
        else:
            clean_topic = topicdate[0]

    if "Regular Press Conference" in title:
        clean_type = "Regular Press Conference"
    elif "Remarks" in title:
        clean_type = "Remarks"
    else:
        clean_type = "No Type"

    # clean the remarks
    clean_remarks = []
    clean_order = []
    clean_contenttype = []
    cleanstring = ''

    order_start = 1
    for x in line:
        clean, question_flag = clean_html_tags(x)
        # print(clean)

        # check if there's a Q: or CNN: at the beginning of line
        q_or_a = bool(re.match("^[A-Za-z ]{1,30}:", clean)) or question_flag
        # print(f'q_or_a: {q_or_a}')
        answer_a = bool(re.match("^A:", clean))
        # print(f'answer_a: {answer_a}')
        answer_name = clean_spox in clean

        answer_flag = answer_a or answer_name
        # print(f'answer_block: {answer_block}')

        if answer_flag:
            blocktype = "A"
        elif question_flag:
            blocktype = "Q"
        else:
            blocktype = "None"

        # if just beginning, set cleaned string as start
        if cleanstring == '':
            cleanstring = clean
            cleantype = blocktype
        # if it's a question or answer, set the start of new clean string
        # to this beginning question or answer
        elif q_or_a:
            # add the cleaned info to list
            clean_remarks.append(cleanstring)
            clean_order.append(order_start)
            clean_contenttype.append(cleantype)

            # reset values
            order_start += 1
            cleanstring = clean
            cleantype = blocktype
        # if it's not the beginning of a section, add it to the string
        else:
            cleanstring = cleanstring + '<br><br>' + clean

    # add the last paragraph to the string
    clean_remarks.append(cleanstring)
    clean_order.append(order_start)
    clean_contenttype.append(cleantype)

    # make dictionary to store cleaned info
    out = {
        "title": title,
        "spox": clean_spox,
        "date": clean_date,
        "topic": clean_topic,
        "type": clean_type,
        "content": clean_remarks,
        "content_order": clean_order,
        "content_type": clean_contenttype,
        'url': clean_url
    }
    clean_output.append(out)

# make it a data frame
full_clean = pd.DataFrame(clean_output)

# explode into rows
expanded_full_clean = full_clean.set_index(['title', 'date', 'spox', 'topic', 'type', 'url']).apply(pd.Series.explode).reset_index()
expanded_full_clean.shape

# read in original file
original = pd.read_csv('C:/Users/clara/Documents/china_fm/china_fm_app/clean_mf.csv', encoding='utf-8', index_col=0)
original.shape

# stack dataframes
stacked = pd.concat([original, expanded_full_clean])
stacked.shape

# remove duplicates
stacked.drop_duplicates(subset=list(stacked), keep='first', inplace=True)
stacked.shape

# write to csv
stacked.to_csv("C:/Users/clara/Documents/china_fm/china_fm_app/clean_mf.csv")
