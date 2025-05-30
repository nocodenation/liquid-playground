FROM python:3.13.3-bookworm

USER root:root
RUN apt-get update && apt-get install -y python3 python3-pip tesseract-ocr tesseract-ocr-eng libtesseract-dev libleptonica-dev pkg-config

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY parse_document.py /app/parse_document.py
COPY dummy.pdf /app/dummy.pdf
COPY dummy.docx /app/dummy.docx
COPY test.sh /app/test.sh
RUN chmod +x /app/test.sh

ENTRYPOINT ["python", "parse_document.py"]
#ENTRYPOINT ["/app/test.sh"]
