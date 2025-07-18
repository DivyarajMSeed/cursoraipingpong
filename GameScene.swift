import SceneKit
import UIKit
import AVFoundation

class GameScene: SCNScene, SCNSceneRendererDelegate {
    weak var gameVC: GameViewController?
    
    // Nodes
    var tableNode: SCNNode!
    var playerPaddle: SCNNode!
    var aiPaddle: SCNNode!
    var ball: SCNNode!
    var leftWall: SCNNode!
    var rightWall: SCNNode!
    var cameraNode: SCNNode!
    
    // Game state
    var score = 0
    var lives = 3
    var isBallActive = false
    var ballVelocity: SCNVector3 = SCNVector3Zero
    var aiSpeed: Float = 0.12
    var lastUpdateTime: TimeInterval = 0
    
    // Sound
    var hitSound: AVAudioPlayer?
    
    // Constants
    let tableWidth: CGFloat = 6.0
    let tableLength: CGFloat = 12.0
    let paddleWidth: CGFloat = 1.2
    let paddleLength: CGFloat = 0.3
    let paddleHeight: CGFloat = 0.2
    let ballRadius: CGFloat = 0.15
    let wallHeight: CGFloat = 0.5
    let wallThickness: CGFloat = 0.1
    let playerZ: CGFloat = -5.5
    let aiZ: CGFloat = 5.5
    
    override init() {
        super.init()
        setupScene()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupScene() {
        // Table
        let tableGeometry = SCNBox(width: tableWidth, height: 0.1, length: tableLength, chamferRadius: 0)
        tableGeometry.firstMaterial?.diffuse.contents = UIColor.green
        tableNode = SCNNode(geometry: tableGeometry)
        tableNode.position = SCNVector3(0, -0.05, 0)
        tableNode.physicsBody = SCNPhysicsBody.static()
        tableNode.physicsBody?.restitution = 0.8
        tableNode.physicsBody?.friction = 0.6
        tableNode.physicsBody?.categoryBitMask = 1
        rootNode.addChildNode(tableNode)
        
        // Player Paddle
        let playerGeometry = SCNBox(width: paddleWidth, height: paddleHeight, length: paddleLength, chamferRadius: 0.05)
        playerGeometry.firstMaterial?.diffuse.contents = UIColor.red
        playerPaddle = SCNNode(geometry: playerGeometry)
        playerPaddle.position = SCNVector3(0, paddleHeight/2, playerZ)
        playerPaddle.physicsBody = SCNPhysicsBody.kinematic()
        playerPaddle.physicsBody?.categoryBitMask = 2
        rootNode.addChildNode(playerPaddle)
        
        // AI Paddle
        let aiGeometry = SCNBox(width: paddleWidth, height: paddleHeight, length: paddleLength, chamferRadius: 0.05)
        aiGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        aiPaddle = SCNNode(geometry: aiGeometry)
        aiPaddle.position = SCNVector3(0, paddleHeight/2, aiZ)
        aiPaddle.physicsBody = SCNPhysicsBody.kinematic()
        aiPaddle.physicsBody?.categoryBitMask = 4
        rootNode.addChildNode(aiPaddle)
        
        // Ball
        let ballGeometry = SCNSphere(radius: ballRadius)
        ballGeometry.firstMaterial?.diffuse.contents = UIColor.white
        ball = SCNNode(geometry: ballGeometry)
        ball.position = SCNVector3(0, ballRadius + 0.1, 0)
        ball.physicsBody = SCNPhysicsBody.dynamic()
        ball.physicsBody?.mass = 0.05
        ball.physicsBody?.restitution = 0.95
        ball.physicsBody?.friction = 0.2
        ball.physicsBody?.damping = 0.01
        ball.physicsBody?.angularDamping = 0.01
        ball.physicsBody?.categoryBitMask = 8
        ball.physicsBody?.contactTestBitMask = 15
        rootNode.addChildNode(ball)
        
        // Side Walls
        let wallLength = tableLength + 1.0
        leftWall = SCNNode(geometry: SCNBox(width: wallThickness, height: wallHeight, length: wallLength, chamferRadius: 0))
        leftWall.position = SCNVector3(-Float(tableWidth/2), Float(wallHeight/2), 0)
        leftWall.geometry?.firstMaterial?.diffuse.contents = UIColor.gray
        leftWall.physicsBody = SCNPhysicsBody.static()
        leftWall.physicsBody?.restitution = 0.9
        leftWall.physicsBody?.categoryBitMask = 16
        rootNode.addChildNode(leftWall)
        
        rightWall = SCNNode(geometry: SCNBox(width: wallThickness, height: wallHeight, length: wallLength, chamferRadius: 0))
        rightWall.position = SCNVector3(Float(tableWidth/2), Float(wallHeight/2), 0)
        rightWall.geometry?.firstMaterial?.diffuse.contents = UIColor.gray
        rightWall.physicsBody = SCNPhysicsBody.static()
        rightWall.physicsBody?.restitution = 0.9
        rightWall.physicsBody?.categoryBitMask = 32
        rootNode.addChildNode(rightWall)
        
        // Camera
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 8, 0)
        cameraNode.eulerAngles = SCNVector3(-Float.pi/3, 0, 0)
        rootNode.addChildNode(cameraNode)
        
        // Lighting
        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 10, 10)
        rootNode.addChildNode(lightNode)
        
        // Physics contact delegate
        let scnView = UIApplication.shared.windows.first?.rootViewController?.view.subviews.compactMap { $0 as? SCNView }.first
        scnView?.scene = self
        scnView?.delegate = self
        scnView?.isPlaying = true
        scnView?.scene?.physicsWorld.contactDelegate = self
        
        // Gesture recognizer
        if let scnView = scnView {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            scnView.addGestureRecognizer(pan)
        }
        
        // Load sound
        if let hitURL = Bundle.main.url(forResource: "hit", withExtension: "wav") {
            hitSound = try? AVAudioPlayer(contentsOf: hitURL)
        }
        
        // Start game
        resetBall()
    }
    
    func resetBall() {
        ball.physicsBody?.clearAllForces()
        ball.position = SCNVector3(0, ballRadius + 0.1, 0)
        ball.physicsBody?.velocity = SCNVector3Zero
        ball.physicsBody?.angularVelocity = SCNVector4Zero
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.launchBall()
        }
    }
    
    func launchBall() {
        let angle = Float.random(in: -0.3...0.3)
        let speed: Float = 6.0
        let direction = SCNVector3(sin(angle) * speed, 0, (Bool.random() ? 1 : -1) * speed)
        ball.physicsBody?.velocity = direction
        ball.physicsBody?.angularVelocity = SCNVector4(0, 1, 0, Float.random(in: 2...4))
        isBallActive = true
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let width = gesture.view!.bounds.width
        let percent = Float(translation.x / width)
        let maxX = Float(tableWidth/2 - paddleWidth/2 - 0.1)
        var newX = playerPaddle.position.x + percent * 6.0
        newX = min(max(newX, -maxX), maxX)
        playerPaddle.position.x = newX
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    // MARK: - SCNSceneRendererDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = time }
        let dt = time - lastUpdateTime
        lastUpdateTime = time
        
        // AI Paddle follows ball
        let aiTargetX = ball.presentation.position.x
        let aiCurrentX = aiPaddle.position.x
        let diff = aiTargetX - aiCurrentX
        let move = max(-aiSpeed, min(aiSpeed, diff))
        let maxX = Float(tableWidth/2 - paddleWidth/2 - 0.1)
        aiPaddle.position.x = min(max(aiCurrentX + move, -maxX), maxX)
        
        // Camera follows ball (slight shake on paddle hit)
        let camBaseY: Float = 8
        let camBaseZ: Float = 0
        cameraNode.position.x = ball.presentation.position.x * 0.2
        cameraNode.position.z = camBaseZ + ball.presentation.position.z * 0.1
        cameraNode.position.y = camBaseY + sin(Float(time) * 2) * 0.05
        
        // Check for scoring
        if isBallActive {
            if ball.presentation.position.z < playerZ - 0.5 {
                // Player missed
                lives -= 1
                gameVC?.updateLives(lives)
                isBallActive = false
                if lives > 0 {
                    resetBall()
                } else {
                    // Game over
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Game Over", message: "Final Score: \(self.score)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Restart", style: .default) { _ in
                            self.score = 0
                            self.lives = 3
                            self.gameVC?.updateScore(self.score)
                            self.gameVC?.updateLives(self.lives)
                            self.resetBall()
                        })
                        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
                    }
                }
            } else if ball.presentation.position.z > aiZ + 0.5 {
                // AI missed
                score += 1
                gameVC?.updateScore(score)
                isBallActive = false
                resetBall()
            }
        }
    }
}

// MARK: - Physics Contact

extension GameScene: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let mask = contact.nodeA.physicsBody!.categoryBitMask | contact.nodeB.physicsBody!.categoryBitMask
        if mask & 2 != 0 && mask & 8 != 0 {
            // Player paddle hit ball
            addSpin(to: ball)
            playHitEffect()
        } else if mask & 4 != 0 && mask & 8 != 0 {
            // AI paddle hit ball
            addSpin(to: ball)
            playHitEffect()
        }
    }
    
    func addSpin(to node: SCNNode) {
        let spin = SCNVector4(0, 1, 0, Float.random(in: 2...5))
        node.physicsBody?.angularVelocity = spin
    }
    
    func playHitEffect() {
        // Camera shake
        let originalY = cameraNode.position.y
        let shake = CABasicAnimation(keyPath: "position.y")
        shake.fromValue = originalY
        shake.toValue = originalY + 0.3
        shake.duration = 0.07
        shake.autoreverses = true
        cameraNode.addAnimation(shake, forKey: "shake")
        // Sound
        hitSound?.play()
    }
}