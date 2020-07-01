import json
import pandas as pd
import re

with open('C:/Users/clara/Documents/china_fm/tutorial/mf_press.json', 'rt', encoding='utf-8') as f:
    data = json.load(f, encoding="utf-8")

def clean_html_tags(remarks):
    clean = re.sub('(?<=<).*?(?=>)', '', remarks)
    clean = re.sub('<', '', clean)
    clean = re.sub('>', '', clean)
    return(clean)

# initialize empty list to store clean output
clean_output = list()

for i in range(0, len(data)):
    print(i)
    entry = data[i]
    title = entry['title'][0]
    line = entry['text']
    clean_url = entry['url']

    # clean title information
    clean_spox = re.findall("(?<=^Foreign Ministry Spokesperson )(.*)(?=')", title)[0]
    topicdate = re.findall("(?<= on )(.*)(?=)", title)

    clean_date = "No Date or Topic"
    clean_topic = "No Date or Topic"
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
    cleanstring = ''

    order_start = 1
    for x in line:
        clean = clean_html_tags(x)

        # check if there's a Q: or CNN: at the beginning of line
        q_or_a = bool(re.match("^[A-Za-z ]{1,50}:", clean))

        # if just beginning, set cleaned string as start
        if cleanstring == '':
            cleanstring = clean
        # if it's a question or answer, set the start of new clean string
        # to this beginning question or answer
        elif q_or_a:
            # add the cleaned info to list
            clean_remarks.append(cleanstring)
            clean_order.append(order_start)
            # reset values
            order_start += 1
            cleanstring = clean
        # if it's not the beginning of a section, add it to the string
        else:
            cleanstring = cleanstring + ' ' + clean

    # make dictionary to store cleaned info
    out = {
        "spox": clean_spox,
        "date": clean_date,
        "topic": clean_topic,
        "type": clean_type,
        "content": clean_remarks,
        "content_order": clean_order,
        'url': clean_url
    }
    clean_output.append(out)


full_clean = pd.DataFrame(clean_output)

expanded_full_clean = full_clean.set_index(['date', 'spox', 'topic', 'type', 'url']).apply(pd.Series.explode).reset_index()
expanded_full_clean.to_csv("C:/Users/clara/Documents/china_fm/clean_mf.csv")
