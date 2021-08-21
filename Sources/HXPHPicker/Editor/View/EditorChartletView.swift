//
//  EditorChartletView.swift
//  HXPHPicker
//
//  Created by Slience on 2021/7/24.
//

import UIKit
#if canImport(Kingfisher)
import Kingfisher
#endif

protocol EditorChartletViewDelegate: AnyObject {
    func chartletView(backClick chartletView: EditorChartletView)
    func chartletView(_ chartletView: EditorChartletView,
                      loadTitleChartlet response: @escaping EditorTitleChartletResponse)
    func chartletView(_ chartletView: EditorChartletView,
                      titleChartlet: EditorChartlet,
                      titleIndex: Int,
                      loadChartletList response: @escaping EditorChartletListResponse)
    func chartletView(_ chartletView: EditorChartletView, didSelectImage image: UIImage, imageData: Data?)
}

class EditorChartletView: UIView {
    weak var delegate: EditorChartletViewDelegate?
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .white)
        view.hidesWhenStopped = true
        return view
    }()
    lazy var titleBgView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        return view
    }()
    lazy var bgView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        return view
    }()
    lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage("hx_photo_edit_pull_down".image, for: .normal)
        button.addTarget(self, action: #selector(didBackButtonClick), for: .touchUpInside)
        return button
    }()
    @objc func didBackButtonClick() {
        delegate?.chartletView(backClick: self)
    }
    lazy var titleFlowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 15
        flowLayout.minimumInteritemSpacing = 0
        return flowLayout
    }()
    lazy var titleView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: titleFlowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.register(EditorChartletViewCell.self, forCellWithReuseIdentifier: "EditorChartletViewCellTitleID")
        return view
    }()
    lazy var listFlowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        return flowLayout
    }()
    
    lazy var listView: UICollectionView = {
        let view = UICollectionView.init(frame: .zero, collectionViewLayout: listFlowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = true
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.register(EditorChartletViewListCell.self, forCellWithReuseIdentifier: "EditorChartletViewListCell_ID")
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressClick(longPress:)))
        view.addGestureRecognizer(longPress)
        return view
    }()
    let editorType: EditorController.EditorType
    var previewView: EditorChartletPreviewView?
    var previewIndex: Int = -1
    let config: EditorChartletConfig
    var titles: [EditorChartletTitle] = []
    var selectedTitleIndex: Int = 0
    var configTitles: [EditorChartlet] = []
    init(
        config: EditorChartletConfig,
        editorType: EditorController.EditorType)
    {
        self.config = config
        self.editorType = editorType
        super.init(frame: .zero)
        setupTitles(config.titles)
        addSubview(bgView)
        addSubview(listView)
        addSubview(titleBgView)
        addSubview(titleView)
        addSubview(backButton)
        addSubview(loadingView)
    }
    
    func setupTitles(_ titleChartlets: [EditorChartlet]) {
        configTitles = titleChartlets
        for (index, title) in titleChartlets.enumerated() {
            let titleChartlet: EditorChartletTitle
            if let image = title.image {
                titleChartlet = EditorChartletTitle(image: image)
            }else {
                #if canImport(Kingfisher)
                if let url = title.url {
                    titleChartlet = EditorChartletTitle(url: url)
                }else {
                    titleChartlet = .init(image: "hx_picker_album_empty".image)
                }
                #else
                titleChartlet = .init(image: "hx_picker_album_empty".image)
                #endif
            }
            if index == 0 {
                titleChartlet.isSelected = true
            }
            titles.append(titleChartlet)
        }
    }
    
    @objc func longPressClick(longPress: UILongPressGestureRecognizer) {
        guard let listCell = listView.cellForItem(at: IndexPath(item: selectedTitleIndex, section: 0)) as? EditorChartletViewListCell else {
            return
        }
        switch longPress.state {
        case .began, .changed:
            let point = longPress.location(in: listCell.collectionView)
            if let indexPath = listCell.collectionView.indexPathForItem(at: point),
               let cell = listCell.collectionView.cellForItem(at: indexPath) as? EditorChartletViewCell {
                if previewIndex == indexPath.item {
                    return
                }
                if let beforeCell = listCell.collectionView.cellForItem(at: IndexPath(item: previewIndex, section: 0)) as? EditorChartletViewCell {
                    beforeCell.showSelectedBgView = false
                }
                previewView?.removeFromSuperview()
                previewView = nil
                previewIndex = indexPath.item
                let keyWindow = UIApplication.shared.keyWindow
                let rect = cell.convert(cell.bounds, to: keyWindow)
                let touchCenter = CGPoint(x: rect.midX, y: rect.midY)
                #if canImport(Kingfisher)
                if let image = cell.chartlet.image {
                    previewView = EditorChartletPreviewView(
                        image: image,
                        touch: touchCenter,
                        touchView: cell.size
                    )
                    keyWindow?.addSubview(previewView!)
                }else if let url = cell.chartlet.url {
                    previewView = EditorChartletPreviewView(
                        imageURL: url,
                        editorType: editorType,
                        touch: touchCenter,
                        touchView: cell.size
                    )
                    keyWindow?.addSubview(previewView!)
                }
                #else
                if let image = cell.chartlet.image {
                    previewView = EditorChartletPreviewView(
                        image: image,
                        touch: touchCenter,
                        touchView: cell.size
                    )
                    keyWindow?.addSubview(previewView!)
                }
                #endif
                cell.showSelectedBgView = true
            }
        case .cancelled, .ended, .failed:
            if let cell = listCell.collectionView.cellForItem(at: IndexPath(item: previewIndex, section: 0)) as? EditorChartletViewCell {
                cell.showSelectedBgView = false
            }
            UIView.animate(withDuration: 0.2) {
                self.previewView?.alpha = 0
            } completion: { _ in
                self.previewView?.removeFromSuperview()
                self.previewView = nil
                self.previewIndex = -1
            }
        default:
            break
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleBgView.frame = CGRect(x: 0, y: 0, width: width, height: 50)
        backButton.frame = CGRect(x: width - 50 - UIDevice.rightMargin, y: 0, width: 50, height: 50)
        bgView.frame = CGRect(x: 0, y: titleBgView.frame.maxY, width: width, height: height - titleBgView.height)
        titleView.frame = CGRect(x: 0, y: 0, width: width, height: 50)
        titleView.contentInset = UIEdgeInsets(top: 5, left: 15 + UIDevice.leftMargin, bottom: 5, right: backButton.width + UIDevice.rightMargin)
        listView.frame = bounds
        loadingView.center = CGPoint(x: width * 0.5, y: height * 0.5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditorChartletView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, EditorChartletViewListCellDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == titleView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorChartletViewCellTitleID", for: indexPath) as! EditorChartletViewCell
            cell.editorType = editorType
            let titleChartlet = titles[indexPath.item]
            cell.titleChartlet = titleChartlet
            return cell
        }else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorChartletViewListCell_ID", for: indexPath) as! EditorChartletViewListCell
            cell.editorType = editorType
            cell.rowCount = config.rowCount
            cell.delegate = self
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == titleView {
            return CGSize(width: 40, height: 40)
        }else {
            return listView.size
        }
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView != listView {
            return
        }
        if config.loadScene == .cellDisplay {
            requestData(index: indexPath.item)
        }
        let titleChartlet = titles[indexPath.item]
        if !titleChartlet.chartletList.isEmpty || !titleChartlet.isLoading {
            let listCell = cell as! EditorChartletViewListCell
            listCell.chartletList = titleChartlet.chartletList
            return
        }
        let listCell = cell as! EditorChartletViewListCell
        listCell.startLoading()
    }
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView != listView {
            return
        }
        let listCell = cell as! EditorChartletViewListCell
        listCell.stopLoad()
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if collectionView == titleView {
            listView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            requestData(index: indexPath.item)
        }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView != listView {
            return
        }
        let currentIndex = currentIndex()
        if currentIndex == selectedTitleIndex {
            return
        }
        let indexPath = IndexPath(item: currentIndex, section: 0)
        titleView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        let titleCell = titleView.cellForItem(at: indexPath) as? EditorChartletViewCell
        titleCell?.isSelectedTitle = true
        titles[currentIndex].isSelected = true
        
        let selectedCell = titleView.cellForItem(at: IndexPath(item: selectedTitleIndex, section: 0)) as? EditorChartletViewCell
        selectedCell?.isSelectedTitle = false
        titles[selectedTitleIndex].isSelected = false
        
        selectedTitleIndex = currentIndex
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView != listView {
            return
        }
        if config.loadScene == .scrollStop {
            requestData(index: currentIndex())
        }
    }
    
    func currentIndex() -> Int {
        let offsetX = listView.contentOffset.x  + (listView.width) * 0.5
        var currentIndex = Int(offsetX / listView.width)
        if currentIndex > titles.count - 1 {
            currentIndex = titles.count - 1
        }
        if currentIndex < 0 {
            currentIndex = 0
        }
        return currentIndex
    }
    
    func requestData(index: Int) {
        let titleChartle = titles[index]
        if !titleChartle.chartletList.isEmpty || titleChartle.isLoading || configTitles.isEmpty {
            return
        }
        titleChartle.isLoading = true
        delegate?.chartletView(self,
                               titleChartlet: configTitles[index],
                               titleIndex: index,
                               loadChartletList: { [weak self] item, chartletList in
            guard let self = self else { return }
            titleChartle.isLoading = false
            self.titles[item].chartletList = chartletList
            let cell = self.listView.cellForItem(at: IndexPath(item: index, section: 0)) as? EditorChartletViewListCell
            cell?.chartletList = titleChartle.chartletList
            cell?.stopLoad()
        })
    }
    func firstRequest() {
        if titles.isEmpty {
            loadingView.startAnimating()
            delegate?.chartletView(self, loadTitleChartlet: { [weak self] titleChartlets in
                guard let self = self else { return }
                self.loadingView.stopAnimating()
                self.setupTitles(titleChartlets)
                if self.config.loadScene == .scrollStop {
                    self.requestData(index: 0)
                }
                self.titleView.reloadData()
                self.listView.reloadData()
            })
            return
        }
        requestData(index: 0)
    }
    func listCell(_ cell: EditorChartletViewListCell, didSelectImage image: UIImage, imageData: Data?) {
        delegate?.chartletView(self, didSelectImage: image, imageData: imageData)
    }
}

protocol EditorChartletViewListCellDelegate: AnyObject {
    func listCell(_ cell: EditorChartletViewListCell, didSelectImage image: UIImage, imageData: Data?)
}

class EditorChartletViewListCell: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    weak var delegate: EditorChartletViewListCellDelegate?
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .white)
        view.hidesWhenStopped = true
        return view
    }()
    
    lazy var flowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 5
        flowLayout.minimumInteritemSpacing = 5
        return flowLayout
    }()
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView.init(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.register(EditorChartletViewCell.self, forCellWithReuseIdentifier: "EditorChartletViewListCellID")
        return view
    }()
    var rowCount: Int = 4
    var chartletList: [EditorChartlet] = [] {
        didSet {
            collectionView.reloadData()
            resetOffset()
        }
    }
    var editorType: EditorController.EditorType = .photo
    
    func resetOffset() {
        collectionView.contentOffset = CGPoint(x: -collectionView.contentInset.left, y: -collectionView.contentInset.top)
    }
    
    func startLoading() {
        loadingView.startAnimating()
    }
    func stopLoad() {
        loadingView.stopAnimating()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(collectionView)
        contentView.addSubview(loadingView)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return chartletList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorChartletViewListCellID", for: indexPath) as! EditorChartletViewCell
        cell.editorType = editorType
        cell.chartlet = chartletList[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let rowCount = !UIDevice.isPortrait && !UIDevice.isPad ? 7 : CGFloat(self.rowCount)
        let margin = collectionView.contentInset.left + collectionView.contentInset.right
        let spacing = flowLayout.minimumLineSpacing * (rowCount - 1)
        let itemWidth = (width - margin - spacing) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        let cell = collectionView.cellForItem(at: indexPath) as! EditorChartletViewCell
        if var image = cell.chartlet.image {
            let imageData: Data?
            if editorType == .photo {
                if let count = image.images?.count,
                   let img = image.images?.first,
                   count > 0 {
                    image = img
                }
                imageData = nil
            }else {
                imageData = cell.chartlet.imageData
            }
            delegate?.listCell(
                self,
                didSelectImage: image,
                imageData: imageData
            )
        }else {
            #if canImport(Kingfisher)
            if let url = cell.chartlet.url, cell.downloadCompletion {
                let options: KingfisherOptionsInfo = []
                PhotoTools.downloadNetworkImage(
                    with: url,
                    cancelOrigianl: false,
                    options: options,
                    completionHandler: { [weak self] (image) in
                    guard let self = self else { return }
                    if let image = image {
                        if self.editorType == .photo {
                            if let data = image.kf.gifRepresentation(),
                               let img = UIImage(data: data) {
                                self.delegate?.listCell(self, didSelectImage: img, imageData: nil)
                                return
                            }
                            self.delegate?.listCell(self, didSelectImage: image, imageData: nil)
                            return
                        }
                        self.delegate?.listCell(self, didSelectImage: image, imageData: image.kf.gifRepresentation())
                    }
                })
            }
            #endif
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
        loadingView.center = CGPoint(x: width * 0.5, y: height * 0.5)
        collectionView.contentInset = UIEdgeInsets(top: 60, left: 15 + UIDevice.leftMargin, bottom: 15 + UIDevice.bottomMargin, right: 15 + UIDevice.rightMargin)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 60, left: UIDevice.leftMargin, bottom: 15 + UIDevice.bottomMargin, right: UIDevice.rightMargin)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EditorChartletViewCell: UICollectionViewCell {
    lazy var selectedBgView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        view.isHidden = true
        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var imageView: ImageView = {
        let view = ImageView()
        view.imageView.contentMode = .scaleAspectFit
        return view
    }()
    var editorType: EditorController.EditorType = .photo
    var downloadCompletion = false
    
    var titleChartlet: EditorChartletTitle! {
        didSet {
            selectedBgView.isHidden = !titleChartlet.isSelected
            #if canImport(Kingfisher)
            setupImage(image: titleChartlet.image, url: titleChartlet.url)
            #else
            setupImage(image: titleChartlet.image)
            #endif
        }
    }
    
    var isSelectedTitle: Bool = false {
        didSet {
            titleChartlet.isSelected = isSelectedTitle
            selectedBgView.isHidden = !titleChartlet.isSelected
        }
    }
    
    var showSelectedBgView: Bool = false {
        didSet {
            selectedBgView.isHidden = !showSelectedBgView
        }
    }
    
    var chartlet: EditorChartlet! {
        didSet {
            selectedBgView.isHidden = true
            #if canImport(Kingfisher)
            setupImage(image: chartlet.image, url: chartlet.url)
            #else
            setupImage(image: chartlet.image)
            #endif
        }
    }
    
    func setupImage(image: UIImage?, url: URL? = nil) {
        downloadCompletion = false
        imageView.image = nil
        #if canImport(Kingfisher)
        if let image = image {
            imageView.image = image
            downloadCompletion = true
        }else if let url = url {
            imageView.my.kf.indicatorType = .activity
            (imageView.my.kf.indicator?.view as? UIActivityIndicatorView)?.color = .white
            let processor = DownsamplingImageProcessor(
                size: CGSize(
                    width: width * 2,
                    height: height * 2
                )
            )
            let options: KingfisherOptionsInfo
            if url.isGif && editorType == .video {
                options = []
            }else {
                options = [
                    .cacheOriginalImage,
                    .processor(processor),
                    .backgroundDecode
                ]
            }
            imageView.my.kf.setImage(
                with: url,
                options: options)
            { [weak self] result in
                switch result {
                case .success(_):
                    self?.downloadCompletion = true
                default:
                    break
                }
            }
        }
        #else
        if let image = image {
            imageView.image = image
        }
        #endif
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(selectedBgView)
        contentView.addSubview(imageView)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        selectedBgView.frame = bounds
        if titleChartlet != nil {
            imageView.size = CGSize(width: 25, height: 25)
            imageView.center = CGPoint(x: width * 0.5, y: height * 0.5)
        }else {
            imageView.frame = CGRect(x: 5, y: 5, width: width - 10, height: height - 10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}