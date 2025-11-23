import json
import os
from nifiapi.flowfiletransform import FlowFileTransform, FlowFileTransformResult
from nifiapi.properties import PropertyDescriptor, StandardValidators, ExpressionLanguageScope

class AttributesFromJSON(FlowFileTransform):
    class Java:
        implements = ['org.apache.nifi.python.processor.FlowFileTransform']

    class ProcessorDetails:
        version = '0.0.1-SNAPSHOT'
        description = 'Creates attributes from a JSON object. Keys become attribute names and values become attribute values.'
        tags = ['json', 'attributes', 'python']

    def __init__(self, **kwargs):
        pass

    JSON_TEXT = PropertyDescriptor(
        name="JSON Text",
        description="The JSON object to parse. Keys will be attribute names, values will be attribute values.",
        required=False,
        validators=[StandardValidators.NON_EMPTY_VALIDATOR],
        expression_language_scope=ExpressionLanguageScope.FLOWFILE_ATTRIBUTES
    )

    JSON_FILE_PATH = PropertyDescriptor(
        name="JSON File Path",
        description="Path to a file containing the JSON object. If provided, 'JSON Text' is ignored.",
        required=False,
        validators=[StandardValidators.NON_EMPTY_VALIDATOR],
        expression_language_scope=ExpressionLanguageScope.FLOWFILE_ATTRIBUTES
    )

    def getPropertyDescriptors(self):
        return [self.JSON_TEXT, self.JSON_FILE_PATH]

    def transform(self, context, flowFile):
        json_content = ""
        
        file_path = context.getProperty(self.JSON_FILE_PATH).evaluateAttributeExpressions(flowFile).getValue()
        
        if file_path:
            if os.path.exists(file_path) and os.path.isfile(file_path):
                try:
                    with open(file_path, 'r') as f:
                        json_content = f.read()
                except Exception as e:
                    # In FlowFileTransform, usually we route to failure on errors
                    self.logger.error(f"Failed to read file {file_path}: {str(e)}")
                    return FlowFileTransformResult(relationship="failure")
            else:
                 self.logger.error(f"File not found: {file_path}")
                 return FlowFileTransformResult(relationship="failure")
        else:
            json_content = context.getProperty(self.JSON_TEXT).evaluateAttributeExpressions(flowFile).getValue()

        if not json_content:
             # If neither is provided or result is empty
             self.logger.error("No JSON content provided via File Path or JSON Text property")
             return FlowFileTransformResult(relationship="failure")

        try:
            data = json.loads(json_content)
        except json.JSONDecodeError as e:
            self.logger.error(f"Invalid JSON content: {str(e)}")
            return FlowFileTransformResult(relationship="failure")

        if not isinstance(data, dict):
             self.logger.error("JSON content must be an object (dictionary)")
             return FlowFileTransformResult(relationship="failure")

        # Convert all values to strings as FlowFile attributes must be strings
        # We handle nested structures by converting them to string representation
        attributes = {}
        for k, v in data.items():
            if isinstance(v, (dict, list)):
                attributes[str(k)] = json.dumps(v)
            else:
                attributes[str(k)] = str(v)

        return FlowFileTransformResult(relationship="success", attributes=attributes)
