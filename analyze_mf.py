import json
import pandas as pd
import re

with open('C:/Users/clara/Documents/china_fm/tutorial/mf_press.json', 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")

def clean_html_tags(remarks):
    clean = re.sub('(?<=<).*?(?=>)', '', remarks)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    clean = re.sub('&nbsp;', ' ', clean)
    return(clean)

# initialize empty list to store clean output
clean_output = list()

for i in range(0, len(data)):
    # print(i)
    entry = data[i]
    title = entry['title'][0]
    line = entry['text']
    clean_url = entry['url']

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
        clean = clean_html_tags(x)
        # print(clean)

        # check if there's a Q: or CNN: at the beginning of line
        q_or_a = bool(re.match("^[A-Za-z ]{1,30}:", clean))
        # print(f'q_or_a: {q_or_a}')
        answer_a = bool(re.match("^A:", clean))
        # print(f'answer_a: {answer_a}')
        answer_name = clean_spox in clean


        answer_block = answer_a or answer_name
        # print(f'answer_block: {answer_block}')
        question_block = q_or_a and not answer_block
        # print(f'question_block: {question_block}')

        if answer_block:
            blocktype = "A"
        elif question_block:
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


full_clean = pd.DataFrame(clean_output)

expanded_full_clean = full_clean.set_index(['title', 'date', 'spox', 'topic', 'type', 'url']).apply(pd.Series.explode).reset_index()
expanded_full_clean.to_csv("C:/Users/clara/Documents/china_fm/china_fm_app/clean_mf.csv")
