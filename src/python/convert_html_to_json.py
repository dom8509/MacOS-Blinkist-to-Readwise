import sys
import json
from bs4 import BeautifulSoup

with open('tmp/page_source.html', 'r') as file:
    page_source = file.read()

    soup = BeautifulSoup(page_source, 'lxml')

    #  Define the CSS selectors for the fields that interest us (book title, chapter and highlight)
    tag_name = 'div'
    class_name_book_title = 'text-markersV2__items__item__subheadline'
    class_name_highlight = 'text-markersV2__items__item__highlight__text'
    class_name_chapter = 'text-markersV2__items__item__highlight__chapter'
    all_css_selectors = ', '.join(
        map(lambda s: tag_name + '.' + s, [class_name_book_title, class_name_highlight, class_name_chapter]
            )
    )

    #  Fetch the fields that interest us
    fetched_results = []
    book_title = ''
    highlight = ''
    chapter = ''
    try:
        selected_tags = soup.select(all_css_selectors)
        if len(selected_tags) == 0:
            print(
                'Error: Could not find all required fields on the Blinkist highlights page.', file=sys.stderr)
        else:
            for tag in selected_tags:
                if (class_name_book_title in tag.attrs['class']):
                    book_title = tag.text
                elif (class_name_highlight in tag.attrs['class']):
                    highlight = tag.text
                else:
                    chapter = tag.text
                    fetched_results.append({
                        'book_title': book_title,
                        'chapter': chapter,
                        'highlight': highlight
                    })

            with open('tmp/page_source_converted.json', 'w') as out_file:
                json.dump(fetched_results, out_file, indent=2)
            print(fetched_results)
    except NoSuchElementException:
        print(
            'Error: Could not find all required fields on the Blinkist highlights page.', file=sys.stderr)
