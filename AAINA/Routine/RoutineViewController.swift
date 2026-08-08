import UIKit

final class RoutineViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    


        private var selectedDate: Date = Date()
        private let dataModel = DataModel()
        private var selectedSegment: Int = 0
        private var steps: [RoutineStep] = []
        private var aiSteps: [AIRoutineStep] = []
        private var aiOutput: AIRoutineOutput?
        private let headerDivider = UIView()
        private let peachOverlay = UIView()

        private var currentUserID: String {
            dataModel.currentUser().id
        }

       

        override func viewDidLoad() {
            super.viewDidLoad()
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            }

            view.applyAINABackground()
            title = "Routine"

            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.largeTitleDisplayMode = .always

            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStepExpand(_:)),
                name: .stepCellDidToggleExpand,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRoutineCompletionDidChange),
                name: .routineCompletionDidChange,
                object: nil
            )

            setupCalendarButton()
            setupCollectionView()
            //setupHeaderDivider()
            loadData()
            setupPeachOverlay()

            let appearance = UINavigationBarAppearance()

            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.ainaTextPrimary
            ]
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.ainaTextPrimary
            ]

            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            aiOutput = dataModel.loadAIRoutine()
            reloadSteps()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            view.applyAINABackground()

            guard let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

            let width = collectionView.bounds.width

            let cellWidth = width - 32
        if flow.estimatedItemSize.width != cellWidth {
                flow.estimatedItemSize = CGSize(width: cellWidth, height: 200)
                collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    
    @objc private func handleExpand() {
        collectionView.performBatchUpdates(nil)
    }



        @objc private func handleStepExpand(_ notification: Notification) {
        guard let tappedCell = notification.object as? StepCollectionViewCell else { return }
        for cell in collectionView.visibleCells.compactMap({ $0 as? StepCollectionViewCell }) {
            guard cell !== tappedCell else { continue }
            cell.collapseProducts(animated: false)
        }
        collectionView.performBatchUpdates({
            collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    
        }

        @objc private func handleRoutineCompletionDidChange() {
            collectionView.reloadSections(IndexSet(integer: 2))
        }



        private func setupCalendarButton() {
            let button = UIButton(type: .system)

            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            let image  = UIImage(systemName: "calendar", withConfiguration: config)

            button.setImage(image, for: .normal)
            button.tintColor       = UIColor.ainaTextPrimary
            button.backgroundColor = UIColor.ainaGlassSurface

            button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
            button.layer.cornerRadius  = 10
            button.layer.shadowColor   = UIColor.ainaCardShadowColor.cgColor
            button.layer.shadowOpacity = 0.1
            button.layer.shadowRadius  = 6
            button.layer.shadowOffset  = CGSize(width: 0, height: 3)

            button.addTarget(self, action: #selector(calendarTapped), for: .touchUpInside)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
        }

        @objc private func calendarTapped() {
            let vc = CalendarPopupViewController()
            vc.modalPresentationStyle = .overFullScreen
            vc.selectedDate = selectedDate

            vc.onDateSelected = { [weak self] date in
                guard let self = self else { return }
                self.selectedDate = date

                if let cell = self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? TimelineContainerCollectionViewCell {
                    cell.updateSelectedDate(date)
                }
                self.collectionView.reloadSections(IndexSet(integer: 2))
            }

            present(vc, animated: false)
        }
    }

   

    extension RoutineViewController {

        private func setupCollectionView() {
            collectionView.delegate   = self
            collectionView.dataSource = self
            collectionView.backgroundColor = .clear
            collectionView.contentInsetAdjustmentBehavior = .automatic

            collectionView.register(
                UINib(nibName: "TimelineContainerCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "TimelineContainerCollectionViewCell"
            )
            collectionView.register(
                UINib(nibName: "StepCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: StepCollectionViewCell.identifier
            )
            collectionView.register(
                UINib(nibName: "Segmented_CollectionReusableView", bundle: nil),
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                withReuseIdentifier: Segmented_CollectionReusableView.identifier
            )
            collectionView.register(
                ProgressCardCollectionViewCell.self,
                forCellWithReuseIdentifier: ProgressCardCollectionViewCell.identifier
            )

            guard let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

            flow.scrollDirection              = .vertical
            flow.sectionInset                 = .zero
            flow.minimumLineSpacing           = 20
            flow.minimumInteritemSpacing      = 0
            flow.sectionHeadersPinToVisibleBounds = false
            flow.estimatedItemSize = CGSize(width: collectionView.bounds.width - 32, height: 200)
        }

        private func loadData() {
            aiOutput = dataModel.loadAIRoutine()
            reloadSteps()
        }

        private func reloadSteps() {
            if let ai = aiOutput {
                aiSteps = selectedSegment == 0 ? ai.morning : ai.evening
                steps = []
            } else {
                aiSteps = []
                steps = selectedSegment == 0
                    ? dataModel.morningSteps(for: currentUserID)
                    : dataModel.eveningSteps(for: currentUserID)
            }
            collectionView.reloadSections(IndexSet(integer: 2))
        }
    }

 

    extension RoutineViewController: UICollectionViewDataSource {

        func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            insetForSectionAt section: Int) -> UIEdgeInsets {
            switch section {
            case 0: return UIEdgeInsets(top: 16, left: 16, bottom: 8, right: 16) // was left: 0, right: 0
            case 1: return UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            case 2: return UIEdgeInsets(top: 2, left: 16, bottom: 20, right: 16)
            default: return .zero
            }
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int { 3 }

        func collectionView(_ collectionView: UICollectionView,
                            numberOfItemsInSection section: Int) -> Int {
            switch section {
            case 0: return 1
            case 1: return 0
            case 2:
                let count = aiOutput != nil ? aiSteps.count : steps.count
                return count + 1
            default: return 0
            }
        }

        func collectionView(_ collectionView: UICollectionView,
                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

            switch indexPath.section {

            case 0:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "TimelineContainerCollectionViewCell",
                    for: indexPath
                ) as! TimelineContainerCollectionViewCell
                cell.onDateSelected = { [weak self] date in
                    self?.selectedDate = date
                    self?.collectionView.reloadSections(IndexSet(integer: 2))
                }
                return cell

            case 1:
                return UICollectionViewCell()

            case 2:

                // Progress card
                if indexPath.item == 0 {
                    let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: ProgressCardCollectionViewCell.identifier,
                        for: indexPath
                    ) as! ProgressCardCollectionViewCell

                    let total   = aiOutput != nil ? aiSteps.count : steps.count
                    let visibleIDs = aiOutput != nil ? aiSteps.map { $0.id } : steps.map { $0.id }
                    let completedIDs = AppDataModel.shared.completedStepIDs(date: selectedDate)
                    let checked = visibleIDs.filter { completedIDs.contains($0) }.count
                    cell.configure(completed: checked, total: total)
                    return cell
                }

                // Step cells
                let index = indexPath.item - 1
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: StepCollectionViewCell.identifier,
                    for: indexPath
                ) as! StepCollectionViewCell

                if aiOutput != nil {
                    let aiStep    = aiSteps[index]
                    let isChecked = AppDataModel.shared.isStepDone(stepID: aiStep.id, date: selectedDate)

                    cell.configure(aiStep: aiStep, isChecked: isChecked)

                    cell.onProductTapped = { product in
                        guard let urlString = product.productURL,
                              let url = URL(string: urlString) else { return }
                        UIApplication.shared.open(url)
                    }

                    cell.shouldAllowCheck = { [weak self] _ in
                        guard let self else { return false }
                        return AppDataModel.shared.isRoutineCompletionEditable(date: self.selectedDate)
                    }

                    cell.checkChanged = { [weak self] checked in
                        guard let self = self else { return }
                        AppDataModel.shared.setStepDone(stepID: aiStep.id, isDone: checked, date: self.selectedDate)
                        NotificationCenter.default.post(name: .routineCompletionDidChange, object: nil)
                        self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 2), indexPath])
                    }

                } else {
                    let step        = steps[index]
                    let ingredients = dataModel.ingredientNames(for: step)
                    let isChecked   = AppDataModel.shared.isStepDone(stepID: step.id, date: selectedDate)

                    cell.configure(step: step, ingredients: ingredients, isChecked: isChecked)

                    cell.onProductTapped = { product in
                        guard let urlString = product.productURL,
                              let url = URL(string: urlString) else { return }
                        UIApplication.shared.open(url)
                    }

                    cell.shouldAllowCheck = { [weak self] _ in
                        guard let self else { return false }
                        return AppDataModel.shared.isRoutineCompletionEditable(date: self.selectedDate)
                    }

                    cell.checkChanged = { [weak self] checked in
                        guard let self = self else { return }
                        AppDataModel.shared.setStepDone(stepID: step.id, isDone: checked, date: self.selectedDate)
                        NotificationCenter.default.post(name: .routineCompletionDidChange, object: nil)
                        self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 2), indexPath])
                    }
                }

                return cell

                default:
                    return UICollectionViewCell()
                }
                }
                }

             

                extension RoutineViewController {

                    func collectionView(_ collectionView: UICollectionView,
                                        viewForSupplementaryElementOfKind kind: String,
                                        at indexPath: IndexPath) -> UICollectionReusableView {

                        guard indexPath.section == 1 else { return UICollectionReusableView() }

                        let header = collectionView.dequeueReusableSupplementaryView(
                            ofKind: UICollectionView.elementKindSectionHeader,
                            withReuseIdentifier: Segmented_CollectionReusableView.identifier,
                            for: indexPath
                        ) as! Segmented_CollectionReusableView

                        header.segmentChanged = { [weak self] index in
                            self?.selectedSegment = index
                            self?.reloadSteps()
                        }

                        return header
                    }
                }
    

    extension RoutineViewController: UICollectionViewDelegateFlowLayout {

        func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            referenceSizeForHeaderInSection section: Int) -> CGSize {
            return section == 1
                ? CGSize(width: collectionView.frame.width, height: 40)
                : .zero
        }
        func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> CGSize {

            let width = collectionView.bounds.width - 32

            switch indexPath.section {
            case 0:
                return CGSize(width: width, height: 80)

            case 2:
                if indexPath.item == 0 {
                    return CGSize(width: width, height: 80)
                }

                // ✅ FIXED WIDTH ALWAYS SAME
                let isExpanded = false // don't depend on cell instance

                let height: CGFloat = isExpanded ? 600 : 295

                return CGSize(width: width, height: height)

            default:
                return .zero
            }
        }
    }



    extension RoutineViewController: UICollectionViewDelegate {

        func collectionView(_ collectionView: UICollectionView,
                            didSelectItemAt indexPath: IndexPath) {

            guard indexPath.section == 2, indexPath.item != 0 else { return }

            let vc = RoutineDetailViewController()
            vc.dataModel = dataModel

            let index = indexPath.item - 1
            if aiOutput != nil {
                vc.aiStep = aiSteps[index]
            } else {
                vc.step = steps[index]
            }

            navigationController?.pushViewController(vc, animated: true)
        }

        private func setupHeaderDivider() {
            headerDivider.backgroundColor = UIColor.white.withAlphaComponent(1)
            headerDivider.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(headerDivider)
            NSLayoutConstraint.activate([
                headerDivider.topAnchor.constraint(equalTo: collectionView.topAnchor),
                headerDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                headerDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                headerDivider.heightAnchor.constraint(equalToConstant: 1)
            ])
        }

        private func setupPeachOverlay() {
            peachOverlay.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(peachOverlay, at: 1)
            NSLayoutConstraint.activate([
                peachOverlay.topAnchor.constraint(equalTo: view.topAnchor),
                peachOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                peachOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                peachOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
