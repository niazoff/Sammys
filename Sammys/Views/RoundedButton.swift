//
//  RoundedButton.swift
//  Sammys
//
//  Created by Natanel Niazoff on 3/5/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import UIKit

class RoundedButton: UIControl {
    let titleLabel = UILabel()
    
    private let roundedLayer = CAShapeLayer()
    private var _backgroundColor: UIColor? {
        didSet { update() }
    }
    
    override var backgroundColor: UIColor? {
        get { return _backgroundColor }
        set { _backgroundColor = newValue }
    }
    
    var cornerRadiusMultiplier = CGFloat(0.25) {
        didSet { update() }
    }
    
    private struct Constants {
        static let titleLabelInset = CGFloat(10)
    }
    
    override init(frame: CGRect) { super.init(frame: frame); setUp() }
    
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    convenience init() { self.init(frame: .zero) }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        update()
    }
    
    private func setUp() {
        self.layer.addSublayer(roundedLayer)
        [titleLabel].forEach { self.addSubview($0) }
        
        titleLabel.textAlignment = .center
        titleLabel.edgesToSuperview(insets: .init(top: Constants.titleLabelInset, left: Constants.titleLabelInset, bottom: Constants.titleLabelInset, right: Constants.titleLabelInset))
    }
    
    private func update() {
        roundedLayer.fillColor = backgroundColor?.cgColor
        roundedLayer.path = UIBezierPath(roundedRect: .init(x: 0, y: 0, width: self.frame.width, height: self.frame.height), cornerRadius: self.frame.height * cornerRadiusMultiplier).cgPath
    }
}
