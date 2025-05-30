import os
import json
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import TesseractOcrOptions, PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption


os.environ["TESSDATA_PREFIX"] = "/usr/share/tesseract-ocr/5/tessdata"
# os.environ["TESSDATA_PREFIX"] = "/usr/share/tesseract/tessdata"


def main():
    source = "/app/dummy.pdf"
    # source = "/home/iztiev/Downloads/dummy.docx"
    # artifacts_path = "/home/iztiev/.cache/docling/models"

    pipeline_options = PdfPipelineOptions()
    pipeline_options.do_ocr = True
    pipeline_options.ocr_options = TesseractOcrOptions()
    converter = DocumentConverter(format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options),
    })

    print("PDF:")
    result = converter.convert(source)
    # print(json.dumps(result.document.export_to_dict(), indent=2))
    print(result.document.export_to_markdown())

    # print("DOCX:")
    # source = "/app/dummy.docx"
    # result = converter.convert(source)
    # print(result.document.export_to_markdown())

if __name__ == "__main__":
    main()
