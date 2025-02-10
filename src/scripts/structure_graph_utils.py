import json
import ntpath


NAMESPACES = {"1.json": "https://purl.brain-bican.org/ontology/mbao/MBA_",
              "17.json": "https://purl.brain-bican.org/ontology/dmbao/DMBA_",
              "10.json": "https://purl.brain-bican.org/ontology/hbao/HBA_",
              "16.json": "https://purl.brain-bican.org/ontology/dhbao/DHBA_",
              "8.json": "https://purl.brain-bican.org/ontology/pbao/PBA_"}


def read_structure_graph(graph_json):
    f = open(graph_json, 'r')
    j = json.loads(f.read())
    data_list = list()
    namespace = NAMESPACES[ntpath.basename(graph_json)]
    for root in j["msg"]:
        tree_recurse(root, data_list, namespace)
    f.close()
    return data_list


def tree_recurse(node, dl, namespace):
    d = dict()
    d["id"] = namespace + str(node["id"])
    label = str(node["name"]).strip()
    if label == "root":
        label = "brain"
    d["name"] = label
    d["acronym"] = node["acronym"]
    d["symbol"] = node["acronym"]
    if node["parent_structure_id"]:
        d["parent_structure_id"] = namespace + str(node["parent_structure_id"])
    # d["subclass_of"] = "UBERON:0002616"
    dl.append(d)

    for child in node["children"]:
        tree_recurse(child, dl, namespace)
