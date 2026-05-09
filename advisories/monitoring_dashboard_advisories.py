import json

def execute_advisories():

    data = [
    {
        "id": "r001",
        "name": "Implement optimized parameterization and memory feedback",
        "description": "-- Create plan guide to force parameterization\nEXEC sp_create_plan_guide \\",
        "server": "[ERPDB]",
        "impactLevel": 0.7,
        "createdAt": 1727043432,
        "updatedAt": 1727043432,
        "observedAt": [1751389346462, 1753692487558],
        "rootCauseAnalysis": [
            {
                "name": "Query Performance Variance",
                "description": "Initial detection of query performance inconsistency",
                "categoryId": "d001a001c001",
                "severity": 2,
                "factorImpact": 0.5
            },
            {
                "name": "Memory Resource Analysis",
                "description": "Verification of memory resource availability",
                "categoryId": "d001a002c002",
                "severity": 0,
                "factorImpact": 0.5
            },
            {
                "name": "Execution Plan Analysis",
                "description": "Investigation of plan cache patterns",
                "categoryId": "d001a001c003",
                "severity": 1,
                "factorImpact": 0.5
            },
            {
                "name": "Parameter Statistics",
                "description": "Analysis of parameter value distributions",
                "categoryId": "d001a001c004",
                "severity": 2,
                "factorImpact": 0.5
            },
            {
                "name": "Memory Grant Pattern",
                "description": "Analysis of memory grant effectiveness",
                "categoryId": "d001a002c002",
                "severity": 1,
                "factorImpact": 0.2
            },
            {
                "name": "The Root Cause",
                "description": "Parameter sniffing causing suboptimal plan caching and memory grants",
                "categoryId": "d001a001c004",
                "severity": 2,
                "factorImpact": 0.7
            }
        ]
    }
    ]
    
    # ✅ Convert Python object to JSON string
    json_string = json.dumps(data, indent=2)
    print(json_string)

    # ✅ Save JSON to file
    with open("export.json", "w") as f:
        json.dump(data, f, indent=2)