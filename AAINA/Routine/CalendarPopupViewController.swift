//
//  CalendarPopupViewController.swift
//  AAINA
//
//  Created by GEU on 27/03/26.
//

import UIKit

final class CalendarPopupViewController: UIViewController {


    var onDateSelected: ((Date) -> Void)?
    var selectedDate: Date = Date()

 

    private let calendar = Calendar.current
    private var currentDate = Date()
    private var dates: [Date] = []

    private let dimView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView



    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 0

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        currentDate = selectedDate
        setupUI()
        generateMonth()
    }

    // MARK: - UI

    private func setupUI() {
        
        
        view.addSubview(containerView)
        // TOP RIGHT BLOB (small)
        let topBlob = UIView()
        topBlob.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.18)
        topBlob.layer.cornerRadius = 100
        topBlob.translatesAutoresizingMaskIntoConstraints = false

        containerView.insertSubview(topBlob, at: 0)

        NSLayoutConstraint.activate([
            topBlob.widthAnchor.constraint(equalToConstant: 180),
            topBlob.heightAnchor.constraint(equalToConstant: 180),
            topBlob.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 40),
            topBlob.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10)
        ])

        //  BOTTOM LEFT BLOB (smaller + softer)
        let bottomBlob = UIView()
        bottomBlob.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.12)
        bottomBlob.layer.cornerRadius = 120
        bottomBlob.translatesAutoresizingMaskIntoConstraints = false

        containerView.insertSubview(bottomBlob, at: 0)

        NSLayoutConstraint.activate([
            bottomBlob.widthAnchor.constraint(equalToConstant: 220),
            bottomBlob.heightAnchor.constraint(equalToConstant: 220),
            bottomBlob.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: -40),
            bottomBlob.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 60)
        ])
        // Dim
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimView.frame = view.bounds
        dimView.alpha = 0
        view.addSubview(dimView)

        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissSelf)))

        // Container
        containerView.backgroundColor = UIColor.ainaLightBlush

        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.05
        containerView.layer.shadowRadius = 20
        containerView.layer.shadowOffset = CGSize(width: 0, height: 10)

        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.2).cgColor

        containerView.layer.cornerRadius = 24
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.clipsToBounds = true

        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.heightAnchor.constraint(equalToConstant: 420)
        ])

        //  HEADER STACK (FIXED UI)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .equalSpacing
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerStack)

        // LEFT: Title + Chevron
        let titleStack = UIStackView()
        titleStack.axis = .horizontal
        titleStack.spacing = 4
        titleStack.alignment = .center

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .left
        titleLabel.isUserInteractionEnabled = true

        let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevron.tintColor = UIColor.ainaCoralPink
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(chevron)

        titleStack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openMonthPicker)))

        // RIGHT: Arrows
        let arrowStack = UIStackView()
        arrowStack.axis = .horizontal
        arrowStack.spacing = 16

        let prev = UIButton(type: .system)
        prev.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prev.tintColor = UIColor.ainaCoralPink
        prev.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)

        let next = UIButton(type: .system)
        next.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        next.tintColor = UIColor.ainaCoralPink
        next.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)

        arrowStack.addArrangedSubview(prev)
        arrowStack.addArrangedSubview(next)

        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(arrowStack)

        // Collection
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CalendarDateCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(collectionView)

        // Done button
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        done.setTitleColor(UIColor.ainaCoralPink, for: .normal)
        done.layer.cornerRadius = 16
        done.layer.borderWidth = 0.8
        done.layer.shadowColor = UIColor.white.cgColor
        done.layer.shadowOpacity = 0.6
        done.layer.shadowRadius = 6
        done.layer.shadowOffset = .zero
        done.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(done)

        // Constraints
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            done.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 12),
            done.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            done.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            done.heightAnchor.constraint(equalToConstant: 50),
            done.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])

        // Animation
        containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        containerView.alpha = 0

        UIView.animate(withDuration: 0.25) {
            self.dimView.alpha = 1
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }

 

    private func generateMonth() {

        dates.removeAll()

        let range = calendar.range(of: .day, in: .month, for: currentDate)!
        let components = calendar.dateComponents([.year, .month], from: currentDate)

        let firstDay = calendar.date(from: components)!
        let weekday = calendar.component(.weekday, from: firstDay)

        for _ in 1..<weekday {
            dates.append(Date.distantPast)
        }

        for day in range {
            var comp = components
            comp.day = day
            dates.append(calendar.date(from: comp)!)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        titleLabel.text = formatter.string(from: currentDate)

        collectionView.reloadData()
    }

    @objc private func prevMonth() {
        currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate)!
        generateMonth()
    }

    @objc private func nextMonth() {
        currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        generateMonth()
    }

    @objc private func openMonthPicker() {
        let picker = MonthYearPickerViewController()
        picker.modalPresentationStyle = UIModalPresentationStyle.overFullScreen

        picker.onDateSelected = { [weak self] date in
            self?.currentDate = date
            self?.generateMonth()
        }

        present(picker, animated: false)
    }

   

    @objc private func doneTapped() {
        onDateSelected?(selectedDate)
        dismiss(animated: false)
    }

    @objc private func dismissSelf() {
        dismiss(animated: false)
    }
}



extension CalendarPopupViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dates.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CalendarDateCell

        let date = dates[indexPath.item]

        if date == Date.distantPast {
            cell.configure(
                text: "",
                selected: false,
                isToday: false
            )
        } else {
            let day = calendar.component(.day, from: date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(date)

            cell.configure(
                text: "\(day)",
                selected: isSelected,
                isToday: isToday
            )
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let date = dates[indexPath.item]
        guard date != Date.distantPast else { return }

        selectedDate = date
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        CGSize(width: collectionView.bounds.width / 7, height: 44)
    }
}



final class MonthYearPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    var onDateSelected: ((Date) -> Void)?

    private let picker = UIPickerView()
    private let months = Calendar.current.monthSymbols
    private let years = Array(2000...2100)

    private var selectedMonth = Calendar.current.component(.month, from: Date()) - 1
    private var selectedYear = Calendar.current.component(.year, from: Date())

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)

        // 🌟 CONTAINER (WHITE CLEAN UI)
        let container = UIView()
        container.backgroundColor = UIColor(
            red: 255/255,
            green: 245/255,
            blue: 247/255,
            alpha: 1   // 🔥 FULLY SOLID
        )
      
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
      
        container.layer.cornerRadius = 20
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 16
        container.layer.shadowOffset = CGSize(width: 0, height: 8)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
       
      
        
        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 250)
        ])

        // PICKER
        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(picker)

        // subtle selection strip (NOT pink)
        DispatchQueue.main.async {
            self.picker.subviews.forEach {
                if $0.bounds.height < 1 {
                    $0.backgroundColor = UIColor.black.withAlphaComponent(0.05)
                }
            }
        }

        // DONE BUTTON (ONLY PINK ELEMENT)
        let done = UIButton(type: .system)
     
        
      
        done.layer.cornerRadius = 14
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        done.setTitleColor(UIColor.ainaCoralPink, for: .normal)
    

       
        done.layer.shadowColor = UIColor.ainaCoralPink.cgColor
        done.layer.shadowOpacity = 0.35
        done.layer.shadowRadius = 10
        
        done.layer.shadowOffset = CGSize(width: 0, height: 4)

        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(done)

        //  CONSTRAINTS
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            done.topAnchor.constraint(equalTo: picker.bottomAnchor),
            done.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            done.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            done.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            done.heightAnchor.constraint(equalToConstant: 44)
        ])
    }



    @objc private func doneTapped() {
        var comp = DateComponents()
        comp.month = selectedMonth + 1
        comp.year = selectedYear

        if let date = Calendar.current.date(from: comp) {
            onDateSelected?(date)
        }

        dismiss(animated: false)
    }
}



extension MonthYearPickerViewController {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return component == 0 ? months.count : years.count
    }


    func pickerView(_ pickerView: UIPickerView,
                    attributedTitleForRow row: Int,
                    forComponent component: Int) -> NSAttributedString? {

        let text = component == 0 ? months[row] : "\(years[row])"

        let isSelected =
            (component == 0 && row == selectedMonth) ||
            (component == 1 && years[row] == selectedYear)

        return NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: isSelected
                    ? UIColor.black
                    : UIColor.black.withAlphaComponent(0.35),
                .font: isSelected
                    ? UIFont.systemFont(ofSize: 20, weight: .semibold)
                    : UIFont.systemFont(ofSize: 18, weight: .regular)
            ]
        )
    }

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {

        if component == 0 {
            selectedMonth = row
        } else {
            selectedYear = years[row]
        }

      
        pickerView.reloadAllComponents()
    }
}
