/*
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Kitura
import SwiftyJSON
import PostgreSQL
import LoggerAPI
import HeliumLogger

//Log.logger = HeliumLogger(.info)

let router = Router()

//
// TechEmpower test 6: plaintext
//
router.get("/plaintext") {
request, response, next in
    response.headers["Server"] = "Kitura"
    response.headers["Content-Type"] = "text/plain"
    try response.status(.OK).send("Hello, world!").end()
}

//
// TechEmpower test 1: JSON serialization
//
router.get("/json") {
request, response, next in
    response.headers["Server"] = "Kitura"
    let result = JSON(["message":"Hello, World!"])
    try response.status(.OK).send(json: result).end()
}

//
// TechEmpower test 2: Single database query (raw, no ORM)
//
router.get("/db") {
request, response, next in
    response.headers["Server"] = "Kitura"
    let result = getRandomRow()
    guard let dict = result.0 else {
        guard let err = result.1 else {
            Log.error("Unknown Error")
            try response.status(.badRequest).send("Unknown error").end()
            return
        }
        Log.error("\(err)")
        try response.status(.badRequest).send("Error: \(err)").end()
        return
    }
    try response.status(.OK).send(json: JSON(dict)).end()
}

//
// TechEmpower test 3: Multiple database queries (raw, no ORM)
// Get param provides number of queries: /queries?queries=N
//
router.get("/queries") {
request, response, next in
    response.headers["Server"] = "Kitura"
    let queriesParam = request.queryParameters["queries"] ?? "1"
    let numQueries = max(1, min(Int(queriesParam) ?? 1, 500))      // Snap to range of 1-500 as per test spec
    var results: [[String:Int]] = []
    for _ in 1...numQueries {
        let result = getRandomRow()
        guard let dict = result.0 else {
            guard let err = result.1 else {
                Log.error("Unknown Error")
                try response.status(.badRequest).send("Unknown error").end()
                return
            }
            Log.error("\(err)")
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        results.append(dict)
    }
    // Return JSON representation of array of results
    try response.status(.OK).send(json: JSON(results)).end()
}

//
// TechEmpower test 4: fortunes (TODO)
//
router.get("/fortunes") {
request, response, next in
    response.headers["Server"] = "Kitura"
    try response.status(.badRequest).send("Not yet implemented").end()
}

//
// TechEmpower test 5: updates (raw, no ORM)
//
router.get("/updates") {
request, response, next in
    response.headers["Server"] = "Kitura"
    let queriesParam = request.queryParameters["queries"] ?? "1"
    let numQueries = max(1, min(Int(queriesParam) ?? 1, 500))      // Snap to range of 1-500 as per test spec
    var results: [[String:Int]] = []
    for _ in 1...numQueries {
        let result = getRandomRow()
        guard let dict = result.0 else {
            guard let err = result.1 else {
                Log.error("Unknown Error")
                try response.status(.badRequest).send("Unknown error").end()
                return
            }
            Log.error("\(err)")
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        do {
            try updateRow(id: dict["id"]!)
        } catch let err as AppError {
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        results.append(dict)
    }

    // Return JSON representation of array of results
    try response.status(.OK).send(json: JSON(results)).end()
}

// Create table 
router.get("/create") {
request, response, next in
    let dbConn = dbConnPool.take()!
    let query = "CREATE TABLE World ("
        + "id integer NOT NULL,"
        + "randomNumber integer NOT NULL default 0,"
        + "PRIMARY KEY  (id)"
        + ");"
    let result = dbConn.exec(statement: query)
    guard result.status() == PGResult.StatusType.commandOK else {
      try response.status(.badRequest).send("<pre>Error: query '\(query)' - status \(result.status())</pre>").end()
      return
    }
    dbConnPool.give(dbConn)
    response.send("<h3>Table 'World' created</h3>")
    next()
}

// Delete table
router.get("/delete") {
request, response, next in
    let dbConn = dbConnPool.take()!
    let query = "DROP TABLE IF EXISTS World"
    let result = dbConn.exec(statement: query)
    guard result.status() == PGResult.StatusType.commandOK else {
      try response.status(.badRequest).send("<pre>Error: query '\(query)' - status \(result.status())</pre>").end()
      return
    }
    dbConnPool.give(dbConn)
    response.send("<h3>Table 'World' deleted</h3>")
    next()
}

// Populate DB with 10k rows
router.get("/populate") {
request, response, next in
    let dbConn = dbConnPool.take()!
    response.status(.OK).send("<h3>Populating World table with \(dbRows) rows</h3><pre>")
    for i in 1...dbRows {
      let rnd = randomNumber(maxValue)
      let query = "INSERT INTO World (id, randomNumber) VALUES (\(i), \(rnd));"
      let result = dbConn.exec(statement: query)
      guard result.status() == PGResult.StatusType.commandOK else {
        try response.status(.badRequest).send("<pre>Error: query '\(query)' - status \(result.status())</pre>").end()
        return
      }
      response.send(".")
    }
    dbConnPool.give(dbConn)
    response.send("</pre><p>Done.</p>")
    next()
}

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
