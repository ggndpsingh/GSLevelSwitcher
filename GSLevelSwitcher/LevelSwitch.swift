//
//  LevelSwitch.swift
//  GSLevelSwitcher
//
//  Created by Gagandeep Singh on 28/8/18.
//  Copyright © 2018 Gagandeep Singh. All rights reserved.
//

import UIKit

public protocol LevelSwitchDelegate: class {
    func levelSwitch(_ levelSwitch: LevelSwitch, didChange level: Int)
    func levelSwitchDidDismiss(_ levelSwitch: LevelSwitch)
}

open class LevelSwitch: UIViewController {
    
    private struct Defaults {
        static let levelHeight: CGFloat = 72
        static let minLevels: Int = 2
        static let maxLevels: Int = 8
    }
    
    public static var new: LevelSwitch {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: self))
        return storyboard.instantiateViewController(withIdentifier: String(describing: self)) as! LevelSwitch
    }
    
    //MARK: - Outlets
    
    @IBOutlet private var visualEffectView: UIVisualEffectView!
    @IBOutlet private var off   : UIView!
    
    @IBOutlet private var stackViewContainer: UIView! {
        didSet {
            stackViewContainer.layer.cornerRadius = 36
            stackViewContainer.layer.masksToBounds = true
        }
    }
    
    @IBOutlet private var stackView: UIStackView! {
        didSet {
            stackView.spacing = 1 / UIScreen.main.scale
        }
    }
    
    //MARK: - Lazy Properties
    
    lazy private var pan: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
    }()
    
    lazy private var tap: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
    }()
    
    //MARK: - Public Properties
    
    public weak var delegate: LevelSwitchDelegate?
    open var levelHeight: CGFloat = Defaults.levelHeight
    open var levels: Int = 4
    open var level: Int = 0
    
    var isTranslucent: Bool = true
    
    //MARK: - Private Properties
    
    private var feedbackGenerator: UISelectionFeedbackGenerator?
    private var views: [UIView] {
        return stackView.subviews
    }
    
    private var _levels: Int {
        switch levels {
        case let x where x > Defaults.maxLevels:
            return Defaults.maxLevels
        case let x where x < Defaults.minLevels:
            return Defaults.minLevels
        default:
            return levels
        }
    }
    
    private var _level: Int {
        return level <= _levels ? level : _levels
    }
}

extension LevelSwitch {
    
    //MARK: - View Lifecycle
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override open var prefersStatusBarHidden: Bool {
        return true
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        if isTranslucent {
            providesPresentationContextTransitionStyle = true
            definesPresentationContext = true
            modalPresentationStyle = .overCurrentContext
        }
        
        stackViewContainer.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        configureLevels()
        updateViews()
    }
    
    private func configureLevels() {
        for i in 0..<_levels {
            stackView.insertArrangedSubview(newLevel(at: i), at: 0)
        }
    }
    
    private func newLevel(at index: Int) -> UIView {
        let level = UIView()
        level.tag = index
        level.alpha = 0.6
        level.backgroundColor = .black
        level.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = level.heightAnchor.constraint(equalToConstant: levelHeight)
        heightConstraint.isActive = true
        heightConstraint.priority = .defaultHigh
        
        return level
    }
}

extension LevelSwitch {
    
    //MARK: - Stacked Views
    
    private var activeViews: [UIView] {
        return Array(
            views
                .filter{ $0 != off }
                .reversed()
                .suffix(_level)
        )
    }
    
    private var inactiveViews: [UIView] {
        return views
            .filter { $0 != off }
            .filter { !activeViews.contains($0) }
    }
    
    private func updateViews() {
        for view in activeViews {
            view.backgroundColor = .white
        }
        
        for view in inactiveViews {
            view.backgroundColor = .black
        }
    }
    
    private var workingHeight: CGFloat {
        return CGFloat(stackView.subviews.count) * levelHeight
    }
}

extension LevelSwitch {
    
    //MARK: - Gesture Handlers
    
    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        switch gesture.state {
        case .ended:
            if !stackViewContainer.frame.contains(gesture.location(in: view)) {
                dismiss(animated: true)
                delegate?.levelSwitchDidDismiss(self)
                return
            }
            
            guard let hitView = views.filter ({ $0.frame.contains(gesture.location(in: stackViewContainer)) }).first else { return }
            let origin = hitView.frame.origin.y
            let index = Int(origin / levelHeight)

            feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator?.prepare()
            setLevel(at: index, with: feedbackGenerator)
            
        default:
            break
        }
    }
    
    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator?.prepare()
            
        case .changed:
            let y = gesture.location(in: stackView).y
            guard 0...workingHeight ~= y else { return }
            let index = Int(y / levelHeight)
            setLevel(at: index, with: feedbackGenerator)
            
        case .cancelled, .ended, .failed:
            feedbackGenerator = nil
            
        default:
            break
        }
    }
    
    private func setLevel(at index: Int, with feedbackGenerator: UISelectionFeedbackGenerator? = nil) {
        let newLevel = views.count - (index + 1)
        guard newLevel != _level else { return }
        level = newLevel
        updateViews()
        delegate?.levelSwitch(self, didChange: _level)

        feedbackGenerator?.selectionChanged()
        feedbackGenerator?.prepare()
    }
}
