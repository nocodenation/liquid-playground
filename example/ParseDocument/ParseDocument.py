import io
import os
import json

from docling.datamodel.document import ConversionResult
from docling.datamodel.base_models import InputFormat, DocumentStream
from docling.datamodel.pipeline_options import TesseractOcrOptions, PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

from nifiapi.flowfiletransform import FlowFileTransform, FlowFileTransformResult
from nifiapi.properties import PropertyDescriptor, StandardValidators, PropertyDependency

PLAIN_TEXT = "Plain Text"
HTML = "HTML"
MARKDOWN = "Markdown"
PDF = "PDF"
EXCEL = "Microsoft Excel"
POWERPOINT = "Microsoft PowerPoint"
WORD = "Microsoft Word"

PARSING_STRATEGY_AUTO = "Automatic"
PARSING_STRATEGY_HIGH_RES = "High Resolution"
PARSING_STRATEGY_OCR_ONLY = "OCR Only"
PARSING_STRATEGY_FAST = "Fast"

SINGLE_DOCUMENT = "Single Document"
DOCUMENT_PER_ELEMENT = "Document Per Element"

TEXT_KEY = "text"
METADATA_KEY = "metadata"


class ParseDocument(FlowFileTransform):
    class Java:
        implements = ["org.apache.nifi.python.processor.FlowFileTransform"]

    class ProcessorDetails:
        version = '1.0.0'
        description = """Parses incoming unstructured text documents and performs optical character recognition (OCR) in order to extract text from PDF and image files.
            The output is formatted as "json-lines" with two keys: 'text' and 'metadata'.
            Note that use of this Processor may require significant storage space and RAM utilization due to third-party dependencies necessary for processing PDF and image files.
            Also note that in order to process PDF or Images, Tesseract and Poppler must be installed on the system."""
        tags = ["text", "embeddings", "vector", "machine learning", "ML", "artificial intelligence", "ai", "document", "langchain", "pdf", "html", "markdown", "word", "excel", "powerpoint"]
        dependencies = []


    INPUT_FORMAT = PropertyDescriptor(
        name="Input Format",
        description="""The format of the input FlowFile. This dictates which TextLoader will be used to parse the input.
            Note that in order to process images or extract tables from PDF files,you must have both 'poppler' and 'tesseract' installed on your system.""",
        allowable_values=[PLAIN_TEXT, HTML, MARKDOWN, PDF, WORD, EXCEL, POWERPOINT],
        required=True,
        default_value=PLAIN_TEXT
    )
    PDF_INFER_TABLE_STRUCTURE = PropertyDescriptor(
        name="Infer Table Structure",
        description="If true, any table that is identified in the PDF will be parsed and translated into an HTML structure. The HTML of that table will then be added to the \
                    Document's metadata in a key named 'text_as_html'. Regardless of the value of this property, the textual contents of the table will be written to the contents \
                    without the structure.",
        allowable_values=["true", "false"],
        default_value="false",
        required=True,
        dependencies=[PropertyDependency(INPUT_FORMAT, PDF)]
    )

    property_descriptors = [INPUT_FORMAT,
                            PDF_INFER_TABLE_STRUCTURE]

    def __init__(self, **kwargs):
        pass

    def getPropertyDescriptors(self):
        return self.property_descriptors


    def get_converter(self, context) -> DocumentConverter:
        pipeline_options = PdfPipelineOptions()
        pipeline_options.do_ocr = True
        pipeline_options.ocr_options = TesseractOcrOptions()
        pipeline_options.do_table_structure = context.getProperty(self.PDF_INFER_TABLE_STRUCTURE).asBoolean()
        return DocumentConverter(
            allowed_formats=[
                InputFormat.HTML,
                InputFormat.PDF,
                InputFormat.MD,
                InputFormat.DOCX,
                InputFormat.XLSX,
                InputFormat.PPTX
            ],
            format_options={
                InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options),
            }
        )

    def get_file_format(self, context, flowFile) -> str:
        input_format = context.getProperty(self.INPUT_FORMAT).evaluateAttributeExpressions(flowFile).getValue()
        if input_format == HTML:
            return "html"
        elif input_format == PDF:
            return "pdf"
        elif input_format == MARKDOWN:
            return "md"
        elif input_format == WORD:
            return "docx"
        elif input_format == EXCEL:
            return "xlsx"
        elif input_format == POWERPOINT:
            return "pptx"
        else:
            return "txt"

    def convert_file(self, context, flowFile) -> ConversionResult:
        os.environ["TESSDATA_PREFIX"] = "/usr/share/tesseract-ocr/5/tessdata"
        converter = self.get_converter(context)
        stream = io.BytesIO(flowFile.getContentsAsBytes())
        source = DocumentStream(
            name=f"flow_file.{self.get_file_format(context, flowFile)}",
            stream=stream
        )
        return converter.convert(source)

    def transform(self, context, flowFile):
        if context.getProperty(self.INPUT_FORMAT).evaluateAttributeExpressions(flowFile).getValue() == PLAIN_TEXT:
            output_json = json.dumps({"text": flowFile.getContentsAsBytes().decode('utf-8')}, indent=2)
        else:
            result = self.convert_file(context, flowFile)
            output_json = json.dumps(result.document.export_to_dict(), indent=2)

        return FlowFileTransformResult(
            "success",
            contents=output_json,
            attributes={"mime.type": "application/json"}
        )
