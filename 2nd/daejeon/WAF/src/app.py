from flask import Flask, request, Response
from lxml import etree

app = Flask(__name__) 

@app.route("/")
def index():
    return '''
        <h1>Upload your XML</h1>
        <form method="POST" action="/parse" enctype="multipart/form-data">
            <textarea name="xml" rows="10" cols="80"></textarea><br>
            <input type="submit" value="Submit XML">
        </form>
    '''

@app.route("/parse", methods=["POST"])
def parse_xml():
    xml_data = request.form.get("xml", "")
    try:
        parser = etree.XMLParser(load_dtd=True, resolve_entities=True)
        root = etree.fromstring(xml_data.encode(), parser=parser)
        result = etree.tostring(root, pretty_print=True).decode()
        return Response(f"<pre>{result}</pre>", mimetype="text/html")
    except Exception as e:
        return f"<p>Error: {str(e)}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)