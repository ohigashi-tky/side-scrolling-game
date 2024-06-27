//
//  GameScene.swift
//  side-scrolling-game
//
//  Created by 大東拓也 on 2024/06/25.
//

import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    private var backgroundMusic: AVAudioPlayer?
    private var player: SKSpriteNode!
    private var ground: SKSpriteNode!
    private var coins: [SKSpriteNode] = []
    private var scoreLabel: SKLabelNode!
    private var score = 0 {
        didSet {
            scoreLabel.text = "スコア: \(score)"
        }
    }
    private var coinAmountLabel: SKLabelNode!
    private var coinAmount = 0 {
        didSet {
            coinAmountLabel.text = "\(coinAmount) ビットコイン"
        }
    }
    private var gameOverLabel: SKLabelNode!
    
    enum PhysicsCategory {
        static let player: UInt32 = 0x1 << 0
        static let obstacle: UInt32 = 0x1 << 1
        static let ground: UInt32 = 0x1 << 2
    }
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -5) // 重力を調整
        setupBackgroundMusic()
        setupBackground()
        setupGround()
        setupPlayer()
        setupScore()
        setupCoinAmount()
        startObstacleGeneration()
        setupCoins()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }
    
    func setupBackgroundMusic() {
        guard let path = Bundle.main.path(forResource: "bgm1", ofType: "mp3") else {
            print("BGM file not found. Searched in bundle: \(Bundle.main.bundlePath)")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            backgroundMusic = try AVAudioPlayer(contentsOf: url)
            backgroundMusic?.numberOfLoops = -1
            backgroundMusic?.volume = 0.5
            backgroundMusic?.play()
            print("BGM should be playing now")
        } catch {
            print("Couldn't load BGM: \(error)")
        }
    }
    
    // BGMの一時停止
    func pauseBackgroundMusic() {
        backgroundMusic?.pause()
    }
    
    // BGMの再開
    func resumeBackgroundMusic() {
        backgroundMusic?.play()
    }
    
    // BGMの停止
    func stopBackgroundMusic() {
        backgroundMusic?.stop()
    }
    
    func setupBackground() {
        let background = SKSpriteNode(color: .cyan, size: self.size)
//        let background = SKSpriteNode(imageNamed: "BackGround")
//        background.size = CGSize(width: 1000, height: self.size.height) // 必要に応じてサイズを調整
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.zPosition = -1
        addChild(background)
    }
    
    func setupGround() {
        ground = SKSpriteNode(color: .green, size: CGSize(width: frame.width, height: 100))
        ground.position = CGPoint(x: frame.midX, y: ground.size.height / 2)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        addChild(ground)
    }
    
    func setupPlayer() {
        player = SKSpriteNode(imageNamed: "Player")
        player.size = CGSize(width: 60, height: 60) // 必要に応じてサイズを調整
        player.xScale = -1
        player.position = CGPoint(x: frame.minX + 100, y: ground.position.y + ground.size.height / 2 + player.size.height / 2 + 10) // 位置を少し上げる
        let smallerSize = CGSize(width: player.size.width * 0.7, height: player.size.height * 1)
        player.physicsBody = SKPhysicsBody(rectangleOf: smallerSize)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
        player.physicsBody?.collisionBitMask = PhysicsCategory.ground
        player.physicsBody?.mass = 0.1 // 質量を小さくする
        addChild(player)
    }
    
    func setupScore() {
        scoreLabel = SKLabelNode(fontNamed: "Arial")
        scoreLabel.text = "スコア: 0"
        scoreLabel.position = CGPoint(x: frame.minX + 100, y: frame.maxY - 80)
        addChild(scoreLabel)
    }
    
    func setupCoinAmount() {
        coinAmountLabel = SKLabelNode(fontNamed: "Arial")
        coinAmountLabel.text = "0 ビットコイン"
        coinAmountLabel.position = CGPoint(x: frame.minX + 130, y: frame.maxY - 140)
        addChild(coinAmountLabel)
    }
    
    // 障害物の生成
    func startObstacleGeneration() {
        let createAndWait = SKAction.run { [weak self] in
            self?.spawnObstacle()
            let waitDuration = Double.random(in: 2...4)
            self?.run(SKAction.wait(forDuration: waitDuration)) { [weak self] in
                self?.startObstacleGeneration()
            }
        }
        
        run(createAndWait)
    }
    
    //　障害物
    func spawnObstacle() {
        //        let obstacle = SKSpriteNode(color: .blue, size: CGSize(width: 50, height: 75)) // 障害物の高さを調整
        let obstacle = SKSpriteNode(imageNamed: "Obstacle1")
        obstacle.size = CGSize(width: 80, height: 80) // 必要に応じてサイズを調整
        obstacle.position = CGPoint(x: frame.maxX + obstacle.size.width / 2, y: ground.position.y + ground.size.height / 2 + obstacle.size.height / 2)
        // 物理ボディのサイズを画像サイズより小さくする
        let smallerSize = CGSize(width: obstacle.size.width * 0.7, height: obstacle.size.height * 1)
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: smallerSize)
        obstacle.physicsBody?.isDynamic = false
        obstacle.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        addChild(obstacle)
        
        let moveLeft = SKAction.moveBy(x: -frame.width - obstacle.size.width, y: 0, duration: 4.0)
        let remove = SKAction.removeFromParent()
        obstacle.run(SKAction.sequence([moveLeft, remove]))
    }

    func setupCoins() {
        // コインを定期的に生成するアクション
        let createCoinAction = SKAction.run { [weak self] in
            self?.createCoin()
        }
        let waitAction = SKAction.wait(forDuration: 1.5) // コインの生成間隔
        let sequence = SKAction.sequence([createCoinAction, waitAction])
        let repeatForever = SKAction.repeatForever(sequence)
        
        run(repeatForever)
    }
    
    func createCoin() {
        let coin = SKSpriteNode(imageNamed: "Coin") // コインの画像を使用
        coin.size = CGSize(width: 30, height: 30) // コインのサイズを調整
        // 画面の高さの中央40%の範囲内でランダムなY座標を生成
        let minY = size.height * 0.15 // 画面の下から30%の位置
        let maxY = size.height * 0.35 // 画面の下から70%の位置
        let randomY = CGFloat.random(in: minY...maxY)
        
        coin.position = CGPoint(x: size.width + coin.size.width/2,
                                y: randomY)
        
        addChild(coin)
        coins.append(coin)
    }
    
    // タッチした時
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesBegan")
        
        if let velocity = player.physicsBody?.velocity {
            print("Player velocity.dy at touch: \(velocity.dy)")
            
            let tolerance: CGFloat = 5 // 許容範囲を設定
            if abs(velocity.dy) < tolerance { // 速度の絶対値が許容範囲内であればジャンプを許可
                player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 55)) // ジャンプ力を調整
                print("Jump applied")
            } else {
                print("Jump not applied, player not on ground")
            }
        } else {
            print("Could not get player velocity")
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if (contact.bodyA.categoryBitMask == PhysicsCategory.player && contact.bodyB.categoryBitMask == PhysicsCategory.obstacle) ||
            (contact.bodyA.categoryBitMask == PhysicsCategory.obstacle && contact.bodyB.categoryBitMask == PhysicsCategory.player) {
            print("Game Over!")
            // ここにゲームオーバー処理を追加
            gameOver()
        }
    }
    
    func gameOver() {
        // ゲームを停止
        self.isPaused = true
        
        // スコア、金額をリセット
        score = 0
        coinAmount = 0
        
        // ゲームオーバーラベルを表示
        if gameOverLabel == nil {
            gameOverLabel = SKLabelNode(fontNamed: "Arial")
            gameOverLabel.text = "ゲームオーバー！"
            gameOverLabel.fontSize = 48
            gameOverLabel.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
            gameOverLabel.zPosition = 100 // 他のノードの上に表示されるようにする
            addChild(gameOverLabel)
        } else {
            gameOverLabel.isHidden = false
        }
        
        // 3秒後にゲームをリスタート
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.restartGame()
        }
    }
    
    func restartGame() {
        // ゲームオーバーラベルを非表示
        gameOverLabel.isHidden = true
        
        // プレイヤーの位置をリセット
        player.position = CGPoint(x: frame.minX + 100, y: ground.position.y + ground.size.height / 2 + player.size.height / 2)
        
        // 全ての障害物を削除
        self.enumerateChildNodes(withName: "obstacle") { (node, stop) in
            node.removeFromParent()
        }
        
        // ゲームを再開
        self.isPaused = false
    }
    
    override func update(_ currentTime: TimeInterval) {
        score += 1

        moveCoins()
        checkCoinCollisions()
    }
    
    func moveCoins() {
        for (index, coin) in coins.enumerated().reversed() {
            coin.position.x -= 4 // コインの移動速度
            
            if coin.position.x < -coin.size.width/2 {
                coin.removeFromParent()
                coins.remove(at: index)
            }
        }
    }
    
    func checkCoinCollisions() {
        for (index, coin) in coins.enumerated().reversed() {
            if player.frame.intersects(coin.frame) {
                collectCoin(coin: coin, at: index)
            }
        }
    }
    
    // コインを集めた時
    func collectCoin(coin: SKSpriteNode, at index: Int) {
        coin.removeFromParent()
        coins.remove(at: index)
        coinAmount += 1
        coinAmountLabel.text = "\(coinAmount) ビットコイン"
        
        // コイン収集時のエフェクトやサウンドを追加することもできます
    }
}
