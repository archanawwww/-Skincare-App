import UIKit

class StepCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "StepCollectionViewCell"
    
    @IBOutlet weak var cardView: UIView!
    
    @IBOutlet weak var checkButton: UIButton!
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var StepNumber: UILabel!
    @IBOutlet weak var stepTitleLabel: UILabel!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var contentStackView: UIStackView!
    
    @IBOutlet weak var keyIngredientsTitleLabel: UILabel!
    @IBOutlet weak var ingredientsStackView: UIStackView!
    
    @IBOutlet weak var arrowButton: UIButton!
    @IBOutlet weak var exploreButton: UIButton!
    @IBOutlet weak var productsContainerView: UIView!
    @IBOutlet weak var productsContainerHeight: NSLayoutConstraint!
    @IBAction func explorePressed(_ sender: UIButton) {
        toggleExpand() }
    
    var arrowTapped: (() -> Void)?
    var shouldAllowCheck: ((Bool) -> Bool)?
    var checkChanged: ((Bool) -> Void)?
    var onProductTapped: ((SkincareProduct) -> Void)?
    

    private var isChecked = false
    private var ingredients: [String] = []
    private(set) var isExpanded = false
    private var products: [SkincareProduct] = []
    private var productsBuilt = false
    
    // Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupProductsContainer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        checkButton.layer.cornerRadius = checkButton.bounds.height / 2
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        shouldAllowCheck = nil
        checkChanged = nil
        onProductTapped = nil
        arrowTapped = nil
        updateCheckboxUI(animated: false)
        ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        productsContainerView.subviews.forEach { $0.removeFromSuperview() }
        productsBuilt = false
        collapseProducts(animated: false)
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attrs = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        let targetSize = CGSize(width: layoutAttributes.frame.width,
                                height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attrs.frame.size = size
        return attrs
    }
    
}

        // UI Setup

        extension StepCollectionViewCell {

            private func setupUI() {
                arrowButton.translatesAutoresizingMaskIntoConstraints = false
                contentView.layer.masksToBounds = false

                cardView.backgroundColor = UIColor.white.withAlphaComponent(0.88)
                cardView.layer.cornerRadius = 24
                cardView.layer.cornerCurve = .continuous
                cardView.layer.masksToBounds = false
                cardView.layer.borderWidth = 0
                cardView.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
                cardView.layer.shadowColor = UIColor.black.cgColor
                cardView.layer.shadowOpacity = 0.07
                cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
                cardView.layer.shadowRadius = 18

                StepNumber.font = .systemFont(ofSize: 11, weight: .semibold)
                StepNumber.textColor = UIColor(red: 160/255, green: 155/255, blue: 175/255, alpha: 1)

                stepTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
                stepTitleLabel.textColor = UIColor(red: 28/255, green: 22/255, blue: 48/255, alpha: 1)

                productNameLabel.font = .systemFont(ofSize: 11, weight: .regular)
                productNameLabel.textColor = UIColor(red: 100/255, green: 95/255, blue: 115/255, alpha: 1)
                productNameLabel.numberOfLines = 1

                separatorView.backgroundColor = UIColor.black.withAlphaComponent(0.06)

                keyIngredientsTitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
                keyIngredientsTitleLabel.textColor = UIColor(red: 160/255, green: 155/255, blue: 175/255, alpha: 1)
                keyIngredientsTitleLabel.text = "KEY INGREDIENTS"

                ingredientsStackView.axis = .vertical
                ingredientsStackView.spacing = 8

                arrowButton.tintColor = UIColor(red: 190/255, green: 185/255, blue: 200/255, alpha: 1)

                checkButton.backgroundColor = .clear
                checkButton.layer.masksToBounds = false
                checkButton.addTarget(self, action: #selector(toggleCheck), for: .touchUpInside)

                updateCheckboxUI(animated: false)
                styleExploreButton(expanded: false)
            }

            private func setupProductsContainer() {
                productsContainerView.clipsToBounds = true
                productsContainerView.isHidden = true
                productsContainerView.alpha = 0
                productsContainerHeight.constant = 0
                productsContainerHeight.priority = .defaultHigh
            }

            private func styleExploreButton(expanded: Bool) {
                if expanded {
                    exploreButton.setAttributedTitle(
                        NSAttributedString(string: "Explore Products  ∧", attributes: [
                            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                            .foregroundColor: UIColor(red: 107/255, green: 94/255, blue: 168/255, alpha: 1)
                        ]),
                        for: .normal
                    )
                    exploreButton.backgroundColor = UIColor(red: 107/255, green: 94/255, blue: 168/255, alpha: 0.08)
                    exploreButton.layer.borderColor = UIColor(red: 107/255, green: 94/255, blue: 168/255, alpha: 0.35).cgColor
                    exploreButton.layer.borderWidth = 1
                } else {
                    exploreButton.setAttributedTitle(
                        NSAttributedString(string: "Explore Products  ∨", attributes: [
                            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                            .foregroundColor: UIColor(red: 140/255, green: 135/255, blue: 155/255, alpha: 1)
                        ]),
                        for: .normal
                    )
                    exploreButton.backgroundColor = UIColor.clear
                    exploreButton.layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor
                    exploreButton.layer.borderWidth = 0.5
                }
                exploreButton.layer.cornerRadius = 14
                exploreButton.layer.cornerCurve = .continuous
            }
        }

        // Configure

        extension StepCollectionViewCell {

            func configure(step: RoutineStep, ingredients: [String], isChecked: Bool) {
                StepNumber.text       = String(format: "STEP %02d", step.stepOrder)
                stepTitleLabel.text   = step.type.rawValue.capitalized
                productNameLabel.text = step.stepTitle
                self.ingredients      = Array(ingredients.prefix(4))
                self.isChecked        = isChecked
                updateCheckboxUI(animated: false)
                buildIngredientsGrid()
                products = SkincareProductDatabase.shared.products(matchingIngredients: self.ingredients)
                productsBuilt = false
                productsContainerView.subviews.forEach { $0.removeFromSuperview() }
            }

            func configure(aiStep: AIRoutineStep, isChecked: Bool) {
                StepNumber.text       = String(format: "STEP %02d", aiStep.stepNumber)
                stepTitleLabel.text   = aiStep.productType.rawValue.capitalized
                productNameLabel.text = aiStep.productName
                self.ingredients      = Array(aiStep.keyIngredients.prefix(4))
                self.isChecked        = isChecked
                updateCheckboxUI(animated: false)
                buildIngredientsGrid()
                products = SkincareProductDatabase.shared.products(matchingIngredients: self.ingredients)
                productsBuilt = false
                productsContainerView.subviews.forEach { $0.removeFromSuperview() }
            }

            func configure(aiStep: AIRoutineStep, isChecked: Bool, isLocked: Bool) {
                configure(aiStep: aiStep, isChecked: isChecked)
                applyLockedState(isLocked)
            }

            func configure(step: RoutineStep, ingredients: [String], isChecked: Bool, isLocked: Bool) {
                configure(step: step, ingredients: ingredients, isChecked: isChecked)
                applyLockedState(isLocked)
            }
        }

        // Lock State

        extension StepCollectionViewCell {
            func applyLockedState(_ locked: Bool) {
                contentView.alpha        = locked ? 0.4 : 1.0
                isUserInteractionEnabled = !locked
            }
        }

        // MARK: - Expand / Collapse

        extension StepCollectionViewCell {

            private func toggleExpand() {
                isExpanded ? collapseProducts(animated: true) : expandProducts(animated: true)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            private func expandProducts(animated: Bool) {
                isExpanded = true
                styleExploreButton(expanded: true)

                if !productsBuilt {
                    buildProductCards()
                    productsBuilt = true
                }

                // Set explicit height so layout engine has a real value
                productsContainerHeight.constant = 380
                productsContainerView.isHidden = false

                if animated {
                    UIView.animate(withDuration: 0.28, delay: 0,
                                   usingSpringWithDamping: 0.85,
                                   initialSpringVelocity: 0.3,
                                   options: .curveEaseOut) {
                        self.productsContainerView.alpha = 1
                        self.layoutIfNeeded()
                    }
                } else {
                    productsContainerView.alpha = 1
                    layoutIfNeeded()
                }

                NotificationCenter.default.post(name: .stepCellDidToggleExpand, object: self)
            }

            func collapseProducts(animated: Bool) {
                guard isExpanded || !productsContainerView.isHidden else { return }
                isExpanded = false
                styleExploreButton(expanded: false)

                if animated {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.productsContainerView.alpha = 0
                        self.productsContainerHeight.constant = 0
                        self.layoutIfNeeded()
                    }, completion: { _ in
                        self.productsContainerView.isHidden = true
                    })
                } else {
                    productsContainerView.alpha = 0
                    productsContainerHeight.constant = 0
                    productsContainerView.isHidden = true
                    layoutIfNeeded()
                }

                NotificationCenter.default.post(name: .stepCellDidToggleExpand, object: self)
            }
        }

        //Product Cards

        extension StepCollectionViewCell {

            private func buildProductCards() {
                productsContainerView.subviews.forEach { $0.removeFromSuperview() }
                guard !products.isEmpty else { return }

                let scrollView = UIScrollView()
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.showsVerticalScrollIndicator   = false
                scrollView.clipsToBounds = false
                scrollView.translatesAutoresizingMaskIntoConstraints = false

                let cardsStack = UIStackView()
                cardsStack.axis         = .horizontal
                cardsStack.spacing      = 12
                cardsStack.alignment    = .top
                cardsStack.translatesAutoresizingMaskIntoConstraints = false

                for product in products {
                    cardsStack.addArrangedSubview(makeProductCard(product))
                }

                scrollView.addSubview(cardsStack)

                let footer = UILabel()
                footer.text          = "Built on ingredients. Products are here to help you discover them."
                footer.font          = .systemFont(ofSize: 11)
                footer.textColor     = UIColor(red: 170/255, green: 165/255, blue: 180/255, alpha: 1)
                footer.textAlignment = .center
                footer.numberOfLines = 2
                footer.translatesAutoresizingMaskIntoConstraints = false

                productsContainerView.addSubview(scrollView)
                productsContainerView.addSubview(footer)

                let scrollTop = scrollView.topAnchor.constraint(equalTo: productsContainerView.topAnchor, constant: 12)
                let scrollHeight = scrollView.heightAnchor.constraint(equalToConstant: 300)
                let footerTop = footer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10)
                [scrollTop, scrollHeight, footerTop].forEach { $0.priority = .defaultHigh }

                NSLayoutConstraint.activate([
                    scrollTop,
                    scrollView.leadingAnchor.constraint(equalTo: productsContainerView.leadingAnchor, constant: 4),
                    scrollView.trailingAnchor.constraint(equalTo: productsContainerView.trailingAnchor, constant: -4),
                    scrollHeight,

                    cardsStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
                    cardsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                    cardsStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                    cardsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                    cardsStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

                    footerTop,
                    footer.leadingAnchor.constraint(equalTo: productsContainerView.leadingAnchor, constant: 12),
                    footer.trailingAnchor.constraint(equalTo: productsContainerView.trailingAnchor, constant: -12),
                    footer.bottomAnchor.constraint(lessThanOrEqualTo: productsContainerView.bottomAnchor, constant: -8)
                ])
            }

            private func makeProductCard(_ product: SkincareProduct) -> UIView {
                let container = UIView()
                container.backgroundColor     = UIColor(red: 252/255, green: 250/255, blue: 255/255, alpha: 1)
                container.layer.cornerRadius  = 20
                container.layer.cornerCurve   = .continuous
                container.layer.borderWidth   = 0.5
                container.layer.borderColor   = UIColor.black.withAlphaComponent(0.07).cgColor
                container.layer.shadowColor   = UIColor.black.cgColor
                container.layer.shadowOpacity = 0.05
                container.layer.shadowRadius  = 12
                container.layer.shadowOffset  = CGSize(width: 0, height: 4)
                container.layer.masksToBounds = false
                container.translatesAutoresizingMaskIntoConstraints = false
                container.widthAnchor.constraint(equalToConstant: 200).isActive = true

                let imageBg = UIView()
                imageBg.backgroundColor    = UIColor(red: 245/255, green: 241/255, blue: 238/255, alpha: 1)
                imageBg.layer.cornerRadius = 14
                imageBg.layer.cornerCurve  = .continuous
                imageBg.clipsToBounds      = true
                imageBg.translatesAutoresizingMaskIntoConstraints = false

                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.tintColor   = UIColor(red: 190/255, green: 180/255, blue: 200/255, alpha: 1)
                imageView.image       = UIImage(systemName: "drop.fill")
                imageView.clipsToBounds = true
                imageView.translatesAutoresizingMaskIntoConstraints = false

                if let urlString = product.imageURL, let url = URL(string: urlString) {
                    URLSession.shared.dataTask(with: url) { data, _, _ in
                        guard let data = data, let img = UIImage(data: data) else { return }
                        DispatchQueue.main.async {
                            imageView.image = img
                            imageView.contentMode = .scaleAspectFill
                        }
                    }.resume()
                }

                imageBg.addSubview(imageView)

                let brandLabel = UILabel()
                brandLabel.text = product.brand.uppercased()
                brandLabel.font = .systemFont(ofSize: 9, weight: .semibold)
                brandLabel.textColor = UIColor(red: 160/255, green: 155/255, blue: 175/255, alpha: 1)
                brandLabel.translatesAutoresizingMaskIntoConstraints = false

                let nameLabel  = UILabel()
                nameLabel.text          = product.name
                nameLabel.font          = .systemFont(ofSize: 14, weight: .bold)
                nameLabel.textColor     = UIColor(red: 28/255, green: 22/255, blue: 48/255, alpha: 1)
                nameLabel.numberOfLines = 2
                nameLabel.translatesAutoresizingMaskIntoConstraints = false

                let pillsStack     = UIStackView()
                pillsStack.axis    = .vertical
                pillsStack.spacing = 5
                pillsStack.translatesAutoresizingMaskIntoConstraints = false

                for ing in product.ingredients.prefix(2) {
                    pillsStack.addArrangedSubview(makeIngPill(ing))
                }

                let btn = UIButton(type: .system)
                btn.setTitle("Explore Product  ↗", for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
                btn.backgroundColor  = UIColor.ainaCoralPink
                btn.setTitleColor(.white, for: .normal)
                btn.layer.cornerRadius = 12
                btn.layer.cornerCurve  = .continuous
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.addAction(UIAction { _ in
                    guard let urlString = product.productURL,
                          let url = URL(string: urlString) else { return }
                    UIApplication.shared.open(url)
                }, for: .touchUpInside)

                container.addSubview(imageBg)
                container.addSubview(brandLabel)
                container.addSubview(nameLabel)
                container.addSubview(pillsStack)
                container.addSubview(btn)

                NSLayoutConstraint.activate([
                    imageBg.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
                    imageBg.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                    imageBg.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                    imageBg.heightAnchor.constraint(equalToConstant: 110),

                    imageView.topAnchor.constraint(equalTo: imageBg.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: imageBg.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: imageBg.trailingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: imageBg.bottomAnchor),

                    brandLabel.topAnchor.constraint(equalTo: imageBg.bottomAnchor, constant: 10),
                    brandLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                    brandLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                    nameLabel.topAnchor.constraint(equalTo: brandLabel.bottomAnchor, constant: 3),
                    nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                    nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                    pillsStack.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
                    pillsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                    pillsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

                    btn.topAnchor.constraint(equalTo: pillsStack.bottomAnchor, constant: 10),
                    btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                    btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                    btn.heightAnchor.constraint(equalToConstant: 36),
                    btn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
                ])

                return container
            }

            private func makeIngPill(_ text: String) -> UIView {
                let pill             = PaddingLabel()
                pill.text            = text
                pill.font            = .systemFont(ofSize: 10, weight: .medium)
                pill.textColor       = UIColor(red: 180/255, green: 90/255, blue: 66/255, alpha: 1)
                pill.backgroundColor = UIColor(red: 253/255, green: 232/255, blue: 226/255, alpha: 1)
                pill.layer.cornerRadius  = 8
                pill.layer.cornerCurve   = .continuous
                pill.layer.masksToBounds = true
                pill.padding = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
                return pill
            }
        }

        // MARK: - Checkbox

        extension StepCollectionViewCell {

            @objc private func toggleCheck() {
                let newValue = !isChecked
                if let allowed = shouldAllowCheck?(newValue), !allowed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    return
                }
                isChecked = newValue

                UIView.animate(withDuration: 0.12, animations: {
                    self.checkButton.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                }) { _ in
                    UIView.animate(withDuration: 0.25, delay: 0,
                                   usingSpringWithDamping: 0.45,
                                   initialSpringVelocity: 7,
                                   options: [],
                                   animations: { self.checkButton.transform = .identity })
                }
                updateCheckboxUI(animated: true)
                checkChanged?(isChecked)
            }

            private func updateCheckboxUI(animated: Bool) {
                let apply = {
                    if self.isChecked {
                        self.checkButton.backgroundColor = UIColor.systemPink.withAlphaComponent(0.5)
                        self.checkButton.setImage(
                            UIImage(systemName: "checkmark")?
                                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)),
                            for: .normal
                        )
                        self.checkButton.tintColor = .white
                        self.checkButton.layer.shadowColor   = UIColor(red: 232/255, green: 90/255, blue: 120/255, alpha: 1).cgColor
                        self.checkButton.layer.shadowOpacity = 0.45
                        self.checkButton.layer.shadowRadius  = 10
                        self.checkButton.layer.shadowOffset  = .zero
                    } else {
                        self.checkButton.backgroundColor = .clear
                        self.checkButton.setImage(
                            UIImage(systemName: "circle")?
                                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .light)),
                            for: .normal
                        )
                        self.checkButton.tintColor = UIColor(red: 200/255, green: 195/255, blue: 210/255, alpha: 1)
                        self.checkButton.layer.shadowOpacity = 0
                    }
                }
                animated ? UIView.animate(withDuration: 0.2, animations: apply) : apply()
            }
        }

        // Ingredients Grid

        extension StepCollectionViewCell {

            private func buildIngredientsGrid() {
                ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                var rowStack: UIStackView?
                for (index, ingredient) in ingredients.enumerated() {
                    if index % 2 == 0 {
                        rowStack = UIStackView()
                        rowStack?.axis         = .horizontal
                        rowStack?.spacing      = 8
                        rowStack?.distribution = .fillEqually
                        ingredientsStackView.addArrangedSubview(rowStack!)
                    }
                    rowStack?.addArrangedSubview(makePill(title: ingredient))
                }
                if ingredients.count % 2 != 0 {
                    rowStack?.addArrangedSubview(UIView())
                }
            }

            private func makePill(title: String) -> PaddingLabel {
                let pill = PaddingLabel()
                pill.text          = title
                pill.textAlignment = .center
                pill.font          = .systemFont(ofSize: 13, weight: .medium)
                pill.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.18)
                pill.textColor       = UIColor.ainaTextPrimary
                pill.layer.borderWidth   = 0.5
                pill.layer.borderColor   = UIColor.ainaCoralPink.withAlphaComponent(0.5).cgColor
                pill.layer.cornerRadius  = 14
                pill.layer.cornerCurve   = .continuous
                pill.layer.masksToBounds = true
                pill.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
                return pill
            }
        }

        // MARK: - Actions

        extension StepCollectionViewCell {
           
    @IBAction func arrowPressed(_ sender: UIButton) {
        arrowTapped?()
    }
}

extension Notification.Name {
    static let stepCellDidToggleExpand = Notification.Name("stepCellDidToggleExpand")
}
 
