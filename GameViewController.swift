import UIKit
import SceneKit
import AVFoundation

class GameViewController: UIViewController {
    var sceneView: SCNView!
    var scoreLabel: UILabel!
    var livesLabel: UILabel!
    var gameScene: GameScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SceneKit view
        sceneView = SCNView(frame: self.view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(sceneView)
        
        // Load the game scene
        gameScene = GameScene()
        gameScene.gameVC = self
        sceneView.scene = gameScene
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = UIColor.black
        
        // Setup UI overlays
        setupUI()
    }
    
    func setupUI() {
        scoreLabel = UILabel(frame: CGRect(x: 20, y: 40, width: 200, height: 40))
        scoreLabel.textColor = .white
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 24)
        scoreLabel.text = "Score: 0"
        self.view.addSubview(scoreLabel)
        
        livesLabel = UILabel(frame: CGRect(x: self.view.bounds.width - 120, y: 40, width: 100, height: 40))
        livesLabel.textColor = .white
        livesLabel.font = UIFont.boldSystemFont(ofSize: 24)
        livesLabel.textAlignment = .right
        livesLabel.text = "Lives: 3"
        livesLabel.autoresizingMask = [.flexibleLeftMargin]
        self.view.addSubview(livesLabel)
    }
    
    func updateScore(_ score: Int) {
        scoreLabel.text = "Score: \(score)"
    }
    
    func updateLives(_ lives: Int) {
        livesLabel.text = "Lives: \(lives)"
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}