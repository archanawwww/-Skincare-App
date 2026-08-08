//
//  SkinLogViewController.swift
//  AAINA
//

import UIKit
import PhotosUI

class SkinLogViewController: UIViewController {

    // MARK: - Callbacks
    var onSave: ((SkinLogEntry) -> Void)?
    var onUpdate: ((SkinLogEntry) -> Void)?

    // MARK: - Editing
    var existingEntry: SkinLogEntry?

    // MARK: - State
    private var isFlareUp              = false
    private var selectedTags           = Set<String>()
    private var existingPhotoFileNames = [String]()   // already saved to disk
    private var selectedPhotos         = [UIImage]()  // newly picked, not yet saved
    private let tagOptions             = ["Acne", "Redness", "Dryness", "Sensitivity", "Breakout", "Texture"]

    // MARK: - Root layout
    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private let blob1        = UIView()
    private let blob2        = UIView()

    // Notes card
    private let notesCard        = UIView()
    private let titleTextField   = UITextField()
    private let notesTextView    = UITextView()
    private let notesPlaceholder = UILabel()
    private let notesSep         = UIView()

    // Photos card
    private let photosCard      = UIView()
    private let photoScrollView = UIScrollView()
    private let photoStrip      = UIStackView()

    // Flare card
    private let flareCard      = UIView()
    private let checkboxButton = UIButton(type: .custom)
    private let tagsContainer  = UIView()
    private let tagsGrid       = UIStackView()

    // Save
    private let saveButton = UIButton(type: .custom)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        setupNavBar()
        setupBlobs()
        setupScrollView()
        setupNotesCard()
        setupPhotosCard()
        setupFlareCard()
        setupSaveButton()
        setupKeyboard()
        populateIfEditing()
    }

    private func populateIfEditing() {
        guard let entry = existingEntry else { return }
        title = "Edit Skin Report"
        saveButton.setTitle("Update Report", for: .normal)

        titleTextField.text = entry.title
        if !entry.note.isEmpty {
            notesTextView.text = entry.note
            notesPlaceholder.isHidden = true
            notesSep.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.5)
        }

        existingPhotoFileNames = entry.photoFileNames
        rebuildPhotoStrip()

        if entry.isFlareUp {
            isFlareUp = true
            checkboxButton.isSelected = true
            tagsContainer.isHidden = false
            tagsContainer.alpha = 1
            selectedTags = Set(entry.flareUps)
            // Highlight pre-selected tag buttons
            DispatchQueue.main.async { self.refreshTagButtonStates() }
        }
    }

    private func refreshTagButtonStates() {
        for row in tagsGrid.arrangedSubviews {
            guard let rowStack = row as? UIStackView else { continue }
            for wrapper in rowStack.arrangedSubviews {
                guard let glass = wrapper as? UIVisualEffectView,
                      let btn = glass.contentView.subviews.first(where: { $0 is UIButton }) as? UIButton,
                      let tagTitle = btn.title(for: .normal) else { continue }
                let selected = selectedTags.contains(tagTitle)
                btn.isSelected        = selected
                glass.backgroundColor = selected ? UIColor.ainaCoralPink.withAlphaComponent(0.75) : .clear
                glass.layer.borderColor = selected ? UIColor.ainaCoralPink.cgColor : UIColor.clear.cgColor
                glass.layer.borderWidth = selected ? 1 : 0
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
        applyButtonGradient()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Navigation bar

    private func setupNavBar() {
        title = "Skin Report"
        navigationController?.navigationBar.prefersLargeTitles = false
        // Share/export only available when editing a saved entry
        guard existingEntry != nil else { return }
        let exportBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportTapped)
        )
        exportBtn.tintColor = .label
        navigationItem.rightBarButtonItem = exportBtn
    }

    @objc private func exportTapped() {

        let text = notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Save newly selected photos temporarily
        let newFileNames = selectedPhotos.compactMap { JournalPhotoStore.save($0) }

        // Combine existing + newly selected photos
        let allFileNames = existingPhotoFileNames + newFileNames

        let entry = SkinLogEntry(
            id: existingEntry?.id ?? UUID().uuidString,
            date: existingEntry?.date ?? Date(),
            isFlareUp: isFlareUp,
            flareUps: Array(selectedTags).sorted(),
            note: text,
            title: title,
            photoFileNames: allFileNames
        )

        let pdf = SkinLogPDFExporter.generate(from: entry)

        let av = UIActivityViewController(
            activityItems: [pdf],
            applicationActivities: nil
        )

        present(av, animated: true)
    }

    // MARK: - Ambient blobs

    private func setupBlobs() {
        blob1.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.22)
        blob1.layer.cornerRadius = 150
        blob1.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blob1)

        blob2.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.13)
        blob2.layer.cornerRadius = 120
        blob2.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blob2)

        NSLayoutConstraint.activate([
            blob1.widthAnchor.constraint(equalToConstant: 300),
            blob1.heightAnchor.constraint(equalToConstant: 300),
            blob1.topAnchor.constraint(equalTo: view.topAnchor, constant: -60),
            blob1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 60),

            blob2.widthAnchor.constraint(equalToConstant: 240),
            blob2.heightAnchor.constraint(equalToConstant: 240),
            blob2.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 50),
            blob2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -50)
        ])

        UIView.animate(withDuration: 8, delay: 0,
                       options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.blob1.transform = CGAffineTransform(translationX: -18, y: 18).scaledBy(x: 1.05, y: 1.05)
        }
        UIView.animate(withDuration: 10, delay: 1.5,
                       options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.blob2.transform = CGAffineTransform(translationX: 12, y: -20).scaledBy(x: 1.07, y: 1.07)
        }
    }

    // MARK: - Scroll view

    private func setupScrollView() {
        scrollView.alwaysBounceVertical  = true
        scrollView.keyboardDismissMode   = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Notes card

    private func setupNotesCard() {
        notesCard.layer.cornerRadius = 20
        notesCard.clipsToBounds = true
        notesCard.translatesAutoresizingMaskIntoConstraints = false
        notesCard.applyGlass(cornerRadius: 20)
        contentView.addSubview(notesCard)

        let badge  = makeIconBadge(systemName: "note.text")
        let header = makeSectionLabel("NOTES")

        // Title field
        titleTextField.placeholder  = "Add a title..."
        titleTextField.font         = .systemFont(ofSize: 17, weight: .semibold)
        titleTextField.textColor    = .ainaTextPrimary
        titleTextField.tintColor    = .ainaCoralPink
        titleTextField.borderStyle  = .none
        titleTextField.translatesAutoresizingMaskIntoConstraints = false

        notesTextView.backgroundColor        = .clear
        notesTextView.font                   = .systemFont(ofSize: 15)
        notesTextView.textColor              = .ainaTextPrimary
        notesTextView.tintColor              = .ainaCoralPink
        notesTextView.textContainerInset     = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        notesTextView.textContainer.lineFragmentPadding = 0  // align cursor with placeholder start
        notesTextView.isScrollEnabled        = false
        notesTextView.delegate               = self
        notesTextView.translatesAutoresizingMaskIntoConstraints = false

        notesPlaceholder.text          = "Describe your skin condition today — redness, dryness, breakouts, reactions..."
        notesPlaceholder.font          = .systemFont(ofSize: 15)
        notesPlaceholder.textColor     = .ainaTextTertiary
        notesPlaceholder.numberOfLines = 0
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        notesSep.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
        notesSep.translatesAutoresizingMaskIntoConstraints = false

        [badge, header, titleTextField, notesSep, notesPlaceholder, notesTextView].forEach { notesCard.addSubview($0) }

        NSLayoutConstraint.activate([
            notesCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            notesCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            notesCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            badge.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: 20),
            badge.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 20),

            header.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            header.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),

            titleTextField.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 12),
            titleTextField.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -20),

            notesSep.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 10),
            notesSep.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 20),
            notesSep.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -20),
            notesSep.heightAnchor.constraint(equalToConstant: 1),

            notesTextView.topAnchor.constraint(equalTo: notesSep.bottomAnchor, constant: 12),
            notesTextView.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 16),
            notesTextView.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -16),
            notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),
            notesTextView.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -16),

            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor),
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor, constant: 4),
            notesPlaceholder.trailingAnchor.constraint(equalTo: notesTextView.trailingAnchor, constant: -4)
        ])
    }

    // MARK: - Photos card

    private func setupPhotosCard() {
        photosCard.layer.cornerRadius = 20
        photosCard.clipsToBounds      = true
        photosCard.translatesAutoresizingMaskIntoConstraints = false
        photosCard.applyGlass(cornerRadius: 20)
        contentView.addSubview(photosCard)

        let badge    = makeIconBadge(systemName: "camera.fill")
        let header   = makeSectionLabel("PHOTOS")

        let subtitle = UILabel()
        subtitle.text          = "Attach photos to include in your report"
        subtitle.font          = .systemFont(ofSize: 12)
        subtitle.textColor     = .ainaTextSecondary
        subtitle.numberOfLines = 1
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        photoScrollView.showsHorizontalScrollIndicator = false
        photoScrollView.translatesAutoresizingMaskIntoConstraints = false

        photoStrip.axis      = .horizontal
        photoStrip.spacing   = 10
        photoStrip.alignment = .center
        photoStrip.translatesAutoresizingMaskIntoConstraints = false
        photoScrollView.addSubview(photoStrip)

        [badge, header, subtitle, photoScrollView].forEach { photosCard.addSubview($0) }

        NSLayoutConstraint.activate([
            photosCard.topAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: 16),
            photosCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            photosCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            badge.topAnchor.constraint(equalTo: photosCard.topAnchor, constant: 20),
            badge.leadingAnchor.constraint(equalTo: photosCard.leadingAnchor, constant: 20),

            header.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            header.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),

            subtitle.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: photosCard.leadingAnchor, constant: 20),
            subtitle.trailingAnchor.constraint(equalTo: photosCard.trailingAnchor, constant: -20),

            photoScrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            photoScrollView.leadingAnchor.constraint(equalTo: photosCard.leadingAnchor),
            photoScrollView.trailingAnchor.constraint(equalTo: photosCard.trailingAnchor),
            photoScrollView.heightAnchor.constraint(equalToConstant: 96),
            photoScrollView.bottomAnchor.constraint(equalTo: photosCard.bottomAnchor, constant: -16),

            photoStrip.topAnchor.constraint(equalTo: photoScrollView.topAnchor),
            photoStrip.leadingAnchor.constraint(equalTo: photoScrollView.leadingAnchor, constant: 16),
            photoStrip.trailingAnchor.constraint(equalTo: photoScrollView.trailingAnchor, constant: -16),
            photoStrip.bottomAnchor.constraint(equalTo: photoScrollView.bottomAnchor),
            photoStrip.heightAnchor.constraint(equalTo: photoScrollView.heightAnchor)
        ])

        rebuildPhotoStrip()
    }

    private func rebuildPhotoStrip() {
        photoStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Existing saved photos
        for (i, name) in existingPhotoFileNames.enumerated() {
            if let img = JournalPhotoStore.load(named: name) {
                photoStrip.addArrangedSubview(makeExistingPhotoTile(image: img, index: i))
            }
        }
        // Newly picked photos
        for (i, image) in selectedPhotos.enumerated() {
            photoStrip.addArrangedSubview(makePhotoTile(image: image, index: i))
        }

        let total = existingPhotoFileNames.count + selectedPhotos.count
        if total < 6 {
            photoStrip.addArrangedSubview(makeAddPhotoTile())
        }
    }

    private func makeExistingPhotoTile(image: UIImage, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80)
        ])
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iv)

        let del = UIButton(type: .system)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor = .ainaDustyRose
        del.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        del.layer.cornerRadius = 10
        del.tag = index
        del.addTarget(self, action: #selector(removeExistingPhoto(_:)), for: .touchUpInside)
        del.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(del)

        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: container.topAnchor),
            iv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            iv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            del.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            del.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            del.widthAnchor.constraint(equalToConstant: 20),
            del.heightAnchor.constraint(equalToConstant: 20)
        ])
        return container
    }

    private func makePhotoTile(image: UIImage, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80)
        ])

        let iv = UIImageView(image: image)
        iv.contentMode    = .scaleAspectFill
        iv.clipsToBounds  = true
        iv.layer.cornerRadius = 14
        iv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iv)

        let del = UIButton(type: .system)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor       = .ainaDustyRose
        del.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        del.layer.cornerRadius = 10
        del.tag = index
        del.addTarget(self, action: #selector(removePhoto(_:)), for: .touchUpInside)
        del.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(del)

        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: container.topAnchor),
            iv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            iv.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            del.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            del.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            del.widthAnchor.constraint(equalToConstant: 20),
            del.heightAnchor.constraint(equalToConstant: 20)
        ])
        return container
    }

    private func makeAddPhotoTile() -> UIView {
        let tile = SLDashedTileView()
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 80),
            tile.heightAnchor.constraint(equalToConstant: 80)
        ])

        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor   = .ainaDustyRose
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)

        let lbl = UILabel()
        lbl.text      = "Add"
        lbl.font      = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = .ainaDustyRose
        lbl.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(lbl)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor, constant: -8),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
            lbl.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            lbl.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 4)
        ])

        tile.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addPhotoTapped)))
        return tile
    }

    // MARK: - Flare card

    private func setupFlareCard() {
        flareCard.layer.cornerRadius = 20
        flareCard.clipsToBounds      = true
        flareCard.translatesAutoresizingMaskIntoConstraints = false
        flareCard.applyGlass(cornerRadius: 20)
        contentView.addSubview(flareCard)

        let cardStack = UIStackView()
        cardStack.axis    = .vertical
        cardStack.spacing = 0
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        flareCard.addSubview(cardStack)

        // Checkbox row
        let checkRow = UIStackView()
        checkRow.axis      = .horizontal
        checkRow.spacing   = 12
        checkRow.alignment = .center

        checkboxButton.setImage(UIImage(systemName: "square"), for: .normal)
        checkboxButton.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
        checkboxButton.tintColor = .ainaCoralPink
        checkboxButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkboxButton.widthAnchor.constraint(equalToConstant: 28),
            checkboxButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)

        let flareLabel       = UILabel()
        flareLabel.text      = "Experiencing a flare-up today?"
        flareLabel.font      = .systemFont(ofSize: 15, weight: .medium)
        flareLabel.textColor = .ainaTextPrimary

        checkRow.addArrangedSubview(checkboxButton)
        checkRow.addArrangedSubview(flareLabel)

        // Tags container (hidden until checkbox ticked)
        tagsContainer.isHidden = true
        tagsContainer.alpha    = 0
        tagsContainer.translatesAutoresizingMaskIntoConstraints = false

        let tagsHeader = makeSectionLabel("WHAT WORSENED?")
        tagsHeader.translatesAutoresizingMaskIntoConstraints = false

        tagsGrid.axis    = .vertical
        tagsGrid.spacing = 8
        tagsGrid.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = UIStackView(arrangedSubviews: [tagsHeader, tagsGrid])
        innerStack.axis    = .vertical
        innerStack.spacing = 12
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        tagsContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: tagsContainer.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: tagsContainer.leadingAnchor),
            innerStack.trailingAnchor.constraint(equalTo: tagsContainer.trailingAnchor),
            innerStack.bottomAnchor.constraint(equalTo: tagsContainer.bottomAnchor)
        ])

        cardStack.addArrangedSubview(checkRow)
        cardStack.addArrangedSubview(tagsContainer)

        NSLayoutConstraint.activate([
            flareCard.topAnchor.constraint(equalTo: photosCard.bottomAnchor, constant: 16),
            flareCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            flareCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cardStack.topAnchor.constraint(equalTo: flareCard.topAnchor, constant: 20),
            cardStack.leadingAnchor.constraint(equalTo: flareCard.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: flareCard.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: flareCard.bottomAnchor, constant: -20)
        ])

        buildTagsGrid()
    }

    private func buildTagsGrid() {
        tagsGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for row in stride(from: 0, to: tagOptions.count, by: 2) {
            let rowStack = UIStackView()
            rowStack.axis         = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing      = 10
            for col in 0..<2 {
                let idx = row + col
                guard idx < tagOptions.count else { break }
                rowStack.addArrangedSubview(makeTagButton(tagOptions[idx]))
            }
            tagsGrid.addArrangedSubview(rowStack)
        }
    }

    private func makeTagButton(_ title: String) -> UIView {
        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.layer.cornerRadius = 20
        glass.clipsToBounds      = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.ainaTextPrimary, for: .normal)
        btn.setTitleColor(.white, for: .selected)
        btn.titleLabel?.font = .systemFont(ofSize: 14)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(tagTapped(_:)), for: .touchUpInside)
        glass.contentView.addSubview(btn)

        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            btn.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
            btn.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor)
        ])
        return glass
    }

    // MARK: - Save button

    private func setupSaveButton() {
        saveButton.setTitle("Save Log", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font   = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.layer.cornerRadius = 16
        saveButton.layer.masksToBounds = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: flareCard.bottomAnchor, constant: 24),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 56),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func applyButtonGradient() {
        guard saveButton.bounds.width > 0 else { return }
        let name = "saveGradient"
        if let existing = saveButton.layer.sublayers?.first(where: { $0.name == name }) as? CAGradientLayer {
            existing.frame = saveButton.bounds; return
        }
        let grad        = CAGradientLayer()
        grad.name       = name
        grad.colors     = [UIColor.ainaCoralPink.cgColor, UIColor.ainaDustyRose.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint   = CGPoint(x: 1, y: 0.5)
        grad.cornerRadius = 16
        grad.frame      = saveButton.bounds
        saveButton.layer.insertSublayer(grad, at: 0)
        saveButton.layer.shadowColor   = UIColor.ainaDustyRose.cgColor
        saveButton.layer.shadowOpacity = 0.35
        saveButton.layer.shadowOffset  = CGSize(width: 0, height: 8)
        saveButton.layer.shadowRadius  = 12
    }

    // MARK: - Shared helpers

    private func makeIconBadge(systemName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .ainaTintedGlassMedium
        container.layer.cornerRadius = 18
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor   = .ainaDustyRose
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 36),
            container.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        return container
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.ainaTextTertiary,
            .kern: 1.4
        ])
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Keyboard

    private func setupKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let info     = note.userInfo,
              let frame    = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        let height = max(0, view.bounds.maxY - frame.minY)
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = height > 0 ? height + 16 : 0
        }
    }

    // MARK: - Actions

    @objc private func addPhotoTapped() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in self?.presentCamera() })
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in self?.presentPicker() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func removePhoto(_ sender: UIButton) {
        guard sender.tag < selectedPhotos.count else { return }
        selectedPhotos.remove(at: sender.tag)
        rebuildPhotoStrip()
    }

    @objc private func removeExistingPhoto(_ sender: UIButton) {
        guard sender.tag < existingPhotoFileNames.count else { return }
        existingPhotoFileNames.remove(at: sender.tag)
        rebuildPhotoStrip()
    }

    @objc private func checkboxTapped() {
        isFlareUp.toggle()
        checkboxButton.isSelected = isFlareUp
        if isFlareUp { tagsContainer.isHidden = false }
        UIView.animate(withDuration: 0.28, animations: {
            self.tagsContainer.alpha = self.isFlareUp ? 1 : 0
        }) { _ in
            if !self.isFlareUp { self.tagsContainer.isHidden = true }
        }
    }

    @objc private func tagTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        if let glass = sender.superview?.superview as? UIVisualEffectView {
            UIView.animate(withDuration: 0.15) {
                glass.backgroundColor = sender.isSelected
                    ? UIColor.ainaCoralPink.withAlphaComponent(0.75)
                    : .clear
                glass.layer.borderColor = sender.isSelected
                    ? UIColor.ainaCoralPink.cgColor
                    : UIColor.clear.cgColor
                glass.layer.borderWidth = sender.isSelected ? 1 : 0
            }
        }
        if let title = sender.title(for: .normal) {
            if sender.isSelected { selectedTags.insert(title) } else { selectedTags.remove(title) }
        }
    }

    @objc private func saveTapped() {
        let text      = notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryTitle = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newFileNames  = selectedPhotos.compactMap { JournalPhotoStore.save($0) }
        let allFileNames  = existingPhotoFileNames + newFileNames

        if let existing = existingEntry {
            // Editing: preserve original id and date
            let updated = SkinLogEntry(
                id:             existing.id,
                date:           existing.date,
                isFlareUp:      isFlareUp,
                flareUps:       Array(selectedTags).sorted(),
                note:           text,
                title:          entryTitle,
                photoFileNames: allFileNames
            )
            onUpdate?(updated)
        } else {
            let entry = SkinLogEntry(
                isFlareUp:      isFlareUp,
                flareUps:       Array(selectedTags).sorted(),
                note:           text,
                title:          entryTitle,
                photoFileNames: allFileNames
            )
            onSave?(entry)
        }
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITextViewDelegate

extension SkinLogViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notesPlaceholder.isHidden = !textView.text.isEmpty
        UIView.animate(withDuration: 0.2) {
            self.notesSep.backgroundColor = textView.text.isEmpty
                ? UIColor.ainaCoralPink.withAlphaComponent(0.15)
                : UIColor.ainaCoralPink.withAlphaComponent(0.5)
        }
    }
}

// MARK: - Photo picking

extension SkinLogViewController: PHPickerViewControllerDelegate,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate {

    fileprivate func presentPicker() {
        var config            = PHPickerConfiguration()
        config.filter         = .images
        config.selectionLimit = max(1, 6 - selectedPhotos.count)
        let picker            = PHPickerViewController(configuration: config)
        picker.delegate       = self
        present(picker, animated: true)
    }

    fileprivate func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let cam           = UIImagePickerController()
        cam.sourceType    = .camera
        cam.allowsEditing = true
        cam.delegate      = self
        present(cam, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        results.prefix(max(0, 6 - selectedPhotos.count)).forEach { result in
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let self, let image = obj as? UIImage else { return }
                DispatchQueue.main.async {
                    self.selectedPhotos.append(image)
                    self.rebuildPhotoStrip()
                }
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        dismiss(animated: true)
        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
            selectedPhotos.append(image)
            rebuildPhotoStrip()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}

// MARK: - Dashed tile

private final class SLDashedTileView: UIView {
    private let dash = CAShapeLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor    = UIColor.ainaCoralPink.withAlphaComponent(0.08)
        layer.cornerRadius = 14
        dash.strokeColor   = UIColor.ainaCoralPink.withAlphaComponent(0.4).cgColor
        dash.fillColor     = UIColor.clear.cgColor
        dash.lineWidth     = 1.5
        dash.lineDashPattern = [5, 3]
        layer.addSublayer(dash)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        dash.frame = bounds
        dash.path  = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
    }
}
