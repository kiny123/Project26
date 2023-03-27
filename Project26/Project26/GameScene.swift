//
//  GameScene.swift
//  Project26
//
//  Created by nikita on 24.03.2023.
//

import CoreMotion
import SpriteKit

enum CollisionTypes: UInt32 {
    case player = 1
    case wall = 2
    case star = 4
    case vortex = 8
    case finish = 16
    case portal = 32
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: SKSpriteNode!
    var lastTouchPosition: CGPoint?
    var motionManager: CMMotionManager?
    var scoreLabel: SKLabelNode!
    var isGameOver = false
    var gameOverLabel: SKLabelNode!
    var newGameLabel: SKLabelNode!
    var currentLevel = 1

    var totalLevels = 2

    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        scoreLabel.text = "Score: 0"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 16, y: 16)
        scoreLabel.zPosition = 2
        addChild(scoreLabel)
        
        gameOverLabel = SKLabelNode(fontNamed: "Chalkduster")
        gameOverLabel.text = "Game Over"
        gameOverLabel.position = CGPoint(x: view.frame.width/2, y: view.frame.height/2 )
        gameOverLabel.zPosition = 2
        gameOverLabel.fontSize = 80

        newGameLabel = SKLabelNode(fontNamed: "Chalkduster")
        newGameLabel.name = "nextlevel"
        newGameLabel.text = "Next level?"
        newGameLabel.position = CGPoint(x: view.frame.width/2, y: view.frame.height/2 - 50)
        newGameLabel.fontSize = 40
        newGameLabel.zPosition = 2
        
        loadLevel()
        createPlayer()
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
       
        motionManager = CMMotionManager()
        motionManager?.startAccelerometerUpdates()

    }
    
    func loadLevel() {
        let level = "level\(currentLevel)"
        guard let levelURL = Bundle.main.url(forResource: level, withExtension: "txt") else {
            fatalError("Could not find level1.txt in the app bundle.")
        }
        guard let levelString = try? String(contentsOf: levelURL) else {
            fatalError("Could not load level1.txt from the app bundle.")
        }

        let lines = levelString.components(separatedBy: "\n")

        for (row, line) in lines.reversed().enumerated() {
            for (column, letter) in line.enumerated() {
                let position = CGPoint(x: (64 * column) + 32, y: (64 * row) + 32)

               addElement(withId: letter, to: position)
            }
        }
    }
    
    func unloadLevel() {
             for node in children {
                 if ["wall", "vortex", "star", "finish", "portal"].contains(node.name) {
                     node.removeFromParent()
                 }
             }
             player.removeFromParent()
         }
    
    func addElement(withId letter: Character, to position: CGPoint) {
             if letter == "x" {
                 addWall(to: position)
             }
             else if letter == "v" {
                 addVortex(to: position)
             }
             else if letter == "s" {
                 addStar(to: position)
             }
             else if letter == "f" {
                 addFinish(to: position)
             }
             else if letter == "p" {
                 addPortal(to: position)
             }
             else if letter == " " {
             }
             else {
                 fatalError("Unknown level letter: \(letter)")
             }
         }
    
    func createPlayer() {
        player = SKSpriteNode(imageNamed: "player")
        player.position = CGPoint(x: 96, y: 672)
        player.zPosition = 1
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 0.5

        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.wall.rawValue
        player.physicsBody?.contactTestBitMask = CollisionTypes.star.rawValue | CollisionTypes.vortex.rawValue | CollisionTypes.finish.rawValue | CollisionTypes.portal.rawValue
        addChild(player)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
        
        for node in nodes(at: location) {
                     if node.name == "nextlevel" {
                         currentLevel += 1
                         if currentLevel > totalLevels {
                             currentLevel = 1
                         }
                         gameOverLabel.removeFromParent()
                         newGameLabel.removeFromParent()
                         unloadLevel()
                         loadLevel()
                         createPlayer()
                         isGameOver = false
                }
            }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard isGameOver == false else { return }
        
        #if targetEnvironment(simulator)
            if let currentTouch = lastTouchPosition {
                let diff = CGPoint(x: currentTouch.x - player.position.x, y: currentTouch.y - player.position.y)
                physicsWorld.gravity = CGVector(dx: diff.x / 100, dy: diff.y / 100)
            }
        #else
            if let accelerometerData = motionManager.accelerometerData {
                physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.y * -50, dy: accelerometerData.acceleration.x * 50)
            }
        #endif
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }

        if nodeA == player {
            playerCollided(with: nodeB)
        } else if nodeB == player {
            playerCollided(with: nodeA)
        }
    }
    
    func playerCollided(with node: SKNode) {
        if node.name == "vortex" {
            player.physicsBody?.isDynamic = false
            isGameOver = true
            score -= 1

            let move = SKAction.move(to: node.position, duration: 0.25)
            let scale = SKAction.scale(to: 0.0001, duration: 0.25)
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([move, scale, remove])

            player.run(sequence) { [weak self] in
                self?.createPlayer()
                self?.isGameOver = false
            }
        } else if node.name == "star" {
            node.removeFromParent()
            score += 1
        } else if node.name == "finish" {
            player.physicsBody?.isDynamic = false
            addChild(gameOverLabel)
            addChild(newGameLabel)
        } else if node.name == "portal" {
            portalAction(portalNode: node)
        }
    }
    
    
    func addWall(to position: CGPoint) {
             let node = SKSpriteNode(imageNamed: "block")
             node.position = position
             node.name = "wall"
             node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
             node.physicsBody?.categoryBitMask = CollisionTypes.wall.rawValue
             node.physicsBody?.isDynamic = false

             addChild(node)
         }

         func addVortex(to position: CGPoint) {
             let node = SKSpriteNode(imageNamed: "vortex")
             node.name = "vortex"
             node.position = position
             node.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 1)))
             node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
             node.physicsBody?.isDynamic = false
             node.physicsBody?.categoryBitMask = CollisionTypes.vortex.rawValue
             node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
             node.physicsBody?.collisionBitMask = 0

             addChild(node)
         }

         func addStar(to position: CGPoint) {
             let node = SKSpriteNode(imageNamed: "star")
             node.name = "star"
             node.position = position
             node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
             node.physicsBody?.isDynamic = false
             node.physicsBody?.categoryBitMask = CollisionTypes.star.rawValue
             node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
             node.physicsBody?.collisionBitMask = 0

             addChild(node)
         }

         func addFinish(to position: CGPoint) {
             let node = SKSpriteNode(imageNamed: "finish")
             node.name = "finish"
             node.position = position
             node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
             node.physicsBody?.isDynamic = false
             node.physicsBody?.categoryBitMask = CollisionTypes.finish.rawValue
             node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
             node.physicsBody?.collisionBitMask = 0

             addChild(node)
         }
    
    func addPortal(to position: CGPoint) {
             let node = SKSpriteNode(imageNamed: "portal")
             node.name = "portal"
             node.xScale = 0.15
             node.yScale = 0.15
             node.position = position

             let scale = SKAction.scale(by: 1.07, duration: 1.5)
             node.run(SKAction.repeatForever(SKAction.sequence([scale, scale.reversed()])))
             node.run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi, duration: 6)))

             node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
             node.physicsBody?.isDynamic = false
             node.physicsBody?.categoryBitMask = CollisionTypes.portal.rawValue
             node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
             node.physicsBody?.collisionBitMask = 0

             addChild(node)
         }
    
    func newLevel() {
        
    }
    
    func portalAction(portalNode: SKNode) {
             player.physicsBody?.isDynamic = false
             let otherPortalNode = children.filter { $0.name == "portal" && $0 != portalNode }.first as? SKSpriteNode

             guard let destination = otherPortalNode?.position else { return }

             let teleportEffect = SKAction.sequence([
                 SKAction.fadeOut(withDuration: 0.3),
                 SKAction.move(to: destination, duration: 0),
                 SKAction.fadeIn(withDuration: 0.3)
             ])

             player.run(teleportEffect)
             for node in children {
                 if ["portal"].contains(node.name) {
                     node.removeFromParent()
                 }
             }
             player.physicsBody?.isDynamic = true

         }


}

