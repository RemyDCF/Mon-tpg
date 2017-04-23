//
//  DeparturesInterfaceController.swift
//  tpg offline
//
//  Created by Alice on 10/06/2016.
//  Copyright © 2016 dacostafaro. All rights reserved.
//

import WatchKit
import Foundation
import Alamofire
import SwiftyJSON

class DeparturesInterfaceController: WKInterfaceController {

    var stop: Stop?
    var departuresList: [Departures]! = []
    var offline = false
    @IBOutlet weak var loadingImage: WKInterfaceImage!
    @IBOutlet weak var departuresTable: WKInterfaceTable!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        loadingImage.setHidden(false)
        departuresTable.setHidden(true)
        stop = (context as? Stop) ?? Stop(empty: true)
        refreshDepartures()
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func refreshDepartures() {
        departuresList = []
        offline = false
        Alamofire.request("https://tpg.asmartcode.com/Departures.php", method: .get, parameters: ["key": "d95be980-0830-11e5-a039-0002a5d5c51b", "stopCode": stop!.stopCode]).responseJSON { response in
                if let data = response.result.value {
                    let departs = JSON(data)
                    for (_, subjson) in departs["departures"] {
                        if AppValues.linesColor[subjson["line"]["lineCode"].string!] == nil {
                            self.departuresList.append(Departures(
                                line: subjson["line"]["lineCode"].string!,
                                direction: subjson["line"]["destinationName"].string!,
                                destinationCode: subjson["line"]["destinationCode"].string!,
                                lineColor: .white,
                                lineBackgroundColor: .white,

                                code: String(subjson["departureCode"].int ?? 0),
                                leftTime: subjson["waitingTime"].string!,
                                timestamp: subjson["timestamp"].string
                                ))
                        } else {
                            self.departuresList.append(Departures(
                                line: subjson["line"]["lineCode"].string!,
                                direction: subjson["line"]["destinationName"].string!,
                                destinationCode: subjson["line"]["destinationCode"].string!,
                                lineColor: AppValues.linesColor[subjson["line"]["lineCode"].string!]!,
                                lineBackgroundColor: AppValues.linesBackgroundColor[subjson["line"]["lineCode"].string!]!,

                                code: String(subjson["departureCode"].int ?? 0),
                                leftTime: subjson["waitingTime"].string!,
                                timestamp: subjson["timestamp"].string
                                ))
                        }
                    }
                } else {
                    self.offline = true
                    let day: String!

                    switch Calendar.current.dateComponents([.weekday], from: Date()).weekday {
                    case 7?:
                        day = "SAM"
                        break
                    case 1?:
                        day = "DIM"
                        break
                    default:
                        day = "LUN"
                        break
                    }

                    if let departuresString = AppValues.offlineDepartures[(self.stop?.stopCode)!] {
                        do {
                            var json = try JSON(data: departuresString.data(using: String.Encoding.utf8)!)
                            if json[day].string != nil {
                                json = try JSON(data: json[day].stringValue.data(using: String.Encoding.utf8)!)
                                for (_, subJson) in json {
                                    if AppValues.linesColor[subJson["ligne"].string!] != nil {
                                        self.departuresList.append(Departures(
                                            line: subJson["ligne"].string!,
                                            direction: subJson["destination"].string!,
                                            destinationCode: "",
                                            lineColor: AppValues.linesColor[subJson["ligne"].string!]!,
                                            lineBackgroundColor: AppValues.linesBackgroundColor[subJson["ligne"].string!]!,
                                            code: nil,
                                            leftTime: "0",
                                            timestamp: subJson["timestamp"].string!
                                        ))
                                    } else {
                                        self.departuresList.append(Departures(
                                            line: subJson["ligne"].string!,
                                            direction: subJson["destination"].string!,
                                            destinationCode: "",
                                            lineColor: .white,
                                            lineBackgroundColor: .gray,
                                            code: nil,
                                            leftTime: "0",
                                            timestamp: subJson["timestamp"].string!
                                        ))
                                    }
                                    self.departuresList.last?.calculateLeftTime()
                                }

                                self.departuresList = self.departuresList.filter({ (depart) -> Bool in
                                    if depart.leftTime != "-1" && Int(depart.leftTime)! <= 60 {
                                        return true
                                    }
                                    return false
                                })

                                self.departuresList.sort(by: { (depart1, depart2) -> Bool in
                                    if Int(depart1.leftTime)! < Int(depart2.leftTime)! {
                                        return true
                                    }
                                    return false
                                })
                            }
                        } catch {

                        }
                    }

                }
                self.refreshTable()
                self.loadingImage.setHidden(true)
                self.departuresTable.setHidden(false)
        }
    }

    func refreshTable() {
        if offline {
            departuresTable.setNumberOfRows(self.departuresList.count + 1, withRowType: "DeparturesRow")
            if let controller = departuresTable.rowController(at: 0) as? DeparturesRowController {
                controller.departure = Departures(
                    line: "",
                    direction: NSLocalizedString("Mode hors ligne", comment: ""),
                    destinationCode: "",
                    lineColor: .white,
                    lineBackgroundColor: .orange,
                    code: nil,
                    leftTime: "offline",
                    timestamp: ""
                )
            }
            for index in 0..<departuresList.count {
                if let controller = departuresTable.rowController(at: index + 1) as? DeparturesRowController {
                    controller.departure = departuresList[index]
                }
            }
        } else {
            departuresTable.setNumberOfRows(self.departuresList.count, withRowType: "DeparturesRow")
            for index in 0..<departuresTable.numberOfRows {
                if let controller = departuresTable.rowController(at: index) as? DeparturesRowController {
                    controller.departure = departuresList[index]
                }
            }
        }
    }

    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        guard let departureRowController = departuresTable.rowController(at: rowIndex) as? DeparturesRowController else {
            return nil
        }
        if departureRowController.departure!.leftTime == "no more" {
            return nil
        }
        return departureRowController.departure
    }
}
