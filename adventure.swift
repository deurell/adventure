import Foundation

let gameDataString = """
{
    "startingRoom": 1,
    "rooms": [
        {
            "id": 1,
            "description": "You're on a sunny beach. The waves crash nearby. There's a dense forest to the north.",
            "paths": {
                "north": {
                    "roomID": 2,
                    "isLocked": false
                }
            },
            "items": []
        },
        {
            "id": 2,
            "description": "You're at the edge of the forest. You hear birds singing. A trail leads east, and the beach is to the south.",
            "paths": {
                "south": {
                    "roomID": 1,
                    "isLocked": false
                },
                "east": {
                    "roomID": 3,
                    "isLocked": false
                }
            },
            "items": []
        },
        {
            "id": 3,
            "description": "You're in a clearing. There's a hut to the west and a river to the east.",
            "paths": {
                "west": {
                    "roomID": 4,
                    "isLocked": false
                },
                "east": {
                    "roomID": 5,
                    "isLocked": false
                }
            },
            "items": []
        },
        {
            "id": 4,
            "description": "You're inside the hut. There's a rusty key on a table.",
            "paths": {
                "east": {
                    "roomID": 3,
                    "isLocked": false
                }
            },
            "items": [
                {
                    "name": "rusty key",
                    "description": "An old rusty key that might be useful.",
                    "useEffects": {
                        "5": {
                            "action": "unlockDoor",
                            "message": "The rusty key unlocked the gate to the dock."
                        }
                    }
                }
            ]
        },
        {
            "id": 5,
            "description": "You're by the river. A dock lies ahead with a gate, but it's locked.",
            "paths": {
                "west": {
                    "roomID": 3,
                    "isLocked": false
                },
                "north": {
                    "roomID": 6,
                    "isLocked": true
                }
            },
            "items": []
        },
        {
            "id": 6,
            "description": "You've reached the dock! There's a boat here.",
            "paths": {},
            "items": [
                {
                    "name": "boat",
                    "description": "A small boat. It looks sturdy enough to help you escape the island.",
                    "useEffects": {
                        "6": {
                            "action": "escapeIsland",
                            "message": "You hop on the boat and row away. You've escaped the island!"
                        }
                    }
                }
            ]
        }
    ]
}

"""

struct Item: Codable {
    let name: String
    let description: String
    let useEffects: [String: UseEffect]?
}

struct UseEffect: Codable {
    let action: String
    let message: String
}

struct Path: Codable {
    let roomID: Int
    var isLocked: Bool
}

struct Room: Codable {
    let id: Int
    let description: String
    var paths: [String: Path]
    var items: [Item]
}

var gameRooms: [Int: Room] = [:]
var currentRoomID: Int = 0
var playerInventory: [Item] = []

struct GameData: Codable {
    let startingRoom: Int
    let rooms: [Room]
}

func loadGameData(from jsonString: String) {
    guard let data = jsonString.data(using: .utf8) else {
        print("Error converting JSON string to Data.")
        return
    }

    let decoder = JSONDecoder()
    do {
        let gameData = try decoder.decode(GameData.self, from: data)
        currentRoomID = gameData.startingRoom
        gameRooms = Dictionary(uniqueKeysWithValues: gameData.rooms.map { ($0.id, $0) })
    } catch {
        print("Error decoding JSON: \(error)")
    }
}

func pickUpItem(_ itemName: String, in roomID: Int) -> Bool {
    guard var room = gameRooms[roomID] else { return false }
    if let index = room.items.firstIndex(where: { $0.name == itemName }) {
        playerInventory.append(room.items[index])
        room.items.remove(at: index)
        gameRooms[roomID] = room
        return true
    }
    return false
}

func lookAround(room: Room) {
    print(room.description)
    
    for item in room.items {
        print("There's a \(item.name) here.")
    }
    
    let availableDirections = room.paths.keys.sorted()
    if availableDirections.isEmpty {
        print("There are no obvious exits from this room.")
    } else {
        print("You can go: \(availableDirections.joined(separator: ", ")).")
    }
}

func move(inDirection direction: String) {
    guard let newPath = gameRooms[currentRoomID]?.paths[direction] else {
        print("You can't go that way.")
        return
    }

    if newPath.isLocked {
        print("The way is blocked by a locked door.")
        return
    }

    currentRoomID = newPath.roomID
    displayCurrentRoomDescription()
}

func useItem(_ itemName: String) {
    if let item = playerInventory.first(where: { $0.name == itemName }),
       let useEffect = item.useEffects?[String(currentRoomID)] {
        
        switch useEffect.action {
        case "unlockDoor":
            if var room = gameRooms[currentRoomID],
               let direction = room.paths.keys.first(where: { room.paths[$0]?.isLocked == true }) {
                room.paths[direction]?.isLocked = false
                gameRooms[currentRoomID] = room
            }
        default:
            print("Unexpected action.")
        }
        
        print(useEffect.message)
    } else {
        print("You don't have a \(itemName) in your inventory or it doesn't have any effect here.")
    }
}


func displayInventory() {
    if playerInventory.isEmpty {
        print("Your inventory is empty.")
    } else {
        print("Inventory:")
        for item in playerInventory {
            print("- \(item.name): \(item.description)")
        }
    }
}

func handleCommand(_ command: String) {
    let tokens = command.split(separator: " ").map(String.init)
    
    switch tokens[0] {
    case "look":
        guard let room = gameRooms[currentRoomID] else { return }
        lookAround(room: room)
    case "go":
        if tokens.count < 2 { print("Go where?") }
        else {
            move(inDirection: tokens[1])
        }
    case "pick":
        if tokens.count >= 3, tokens[1] == "up" {
            let itemName = tokens.dropFirst(2).joined(separator: " ")
            if pickUpItem(itemName, in: currentRoomID) {
                print("You picked up the \(itemName).")
            } else {
                print("There's no \(itemName) here.")
            }
        }
    case "use":
        if tokens.count >= 2 {
            let itemName = tokens.dropFirst().joined(separator: " ")
            useItem(itemName)
        }
    case "inventory":
        displayInventory()
    case "exit":
        exit(0)
    default:
        print("I don't understand.")
    }
}

func displayCurrentRoomDescription() {
    if let room = gameRooms[currentRoomID] {
        print(room.description)
    } else {
        print("You find yourself in an unknown location.")
    }
}

func mainGame() {
    loadGameData(from: gameDataString)
    displayCurrentRoomDescription()

    while true {
        print("What would you like to do?")
        if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
            handleCommand(input.lowercased())
        } else {
            print("Please provide a valid command.")
        }
    }
}

mainGame()
