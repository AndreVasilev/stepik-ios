//
//  MatchingQuizViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 16.01.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import UIKit
import FLKAutoLayout

class MatchingQuizViewController: QuizViewController {

    var firstTableView = FullHeightTableView(frame: CGRect.zero, style: UITableViewStyle.plain)
    var secondTableView = FullHeightTableView(frame: CGRect.zero, style: UITableViewStyle.plain)
        
    var firstWebViewHelper : ControllerQuizWebViewHelper!
    var secondWebViewHelper : ControllerQuizWebViewHelper!
    var secondTableViewHeight : NSLayoutConstraint?
    
    var firstUpdateFinished: Bool = false
    var secondUpdateFinished: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        firstTableView.tableFooterView = UIView()
        secondTableView.tableFooterView = UIView()
        firstTableView.tag = 1
        secondTableView.tag = 2
        
        firstTableView.isScrollEnabled = false
        secondTableView.isScrollEnabled = false
        
        firstTableView.backgroundColor = UIColor.clear
        secondTableView.backgroundColor = UIColor.clear

        firstTableView.delegate = self
        firstTableView.dataSource = self
        secondTableView.delegate = self
        secondTableView.dataSource = self

        self.containerView.addSubview(firstTableView)
        self.containerView.addSubview(secondTableView)
        
        firstTableView.alignTop("0", bottom: "0", to: self.containerView)
        firstTableView.alignLeadingEdge(with: self.containerView, predicate: "0")
        firstTableView.constrainWidth(to: self.containerView, predicate: "*0.5")
        
        secondTableView.alignTop("0", bottom: "0", to: self.containerView)
        secondTableView.alignTrailingEdge(with: self.containerView, predicate: "0")
        secondTableView.constrainWidth(to: self.containerView, predicate: "*0.5")

        
        firstTableView.register(UINib(nibName: "SortingQuizTableViewCell", bundle: nil), forCellReuseIdentifier: "SortingQuizTableViewCell")
        secondTableView.register(UINib(nibName: "SortingQuizTableViewCell", bundle: nil), forCellReuseIdentifier: "SortingQuizTableViewCell")
        firstTableView.register(UINib(nibName: "MatchingQuizTableViewCell", bundle: nil), forCellReuseIdentifier: "MatchingQuizTableViewCell")
        secondTableView.register(UINib(nibName: "MatchingQuizTableViewCell", bundle: nil), forCellReuseIdentifier: "MatchingQuizTableViewCell")
        
        initWebViewHelpers()
        
        secondTableView.isEditing = true
        firstTableView.isUserInteractionEnabled = false
        
        // Do any additional setup after loading the view.
    }

    fileprivate func initWebViewHelpers() {
        firstWebViewHelper = ControllerQuizWebViewHelper(tableView: firstTableView, countClosure: {
            [weak self] in
            return self?.optionsCount ?? 0
        }, success: {
            [weak self] in
            guard let s = self else { return }
            s.firstUpdateFinished = true
            if s.secondUpdateFinished {
                s.secondTableView.reloadData()
            }
        })
        
        secondWebViewHelper = ControllerQuizWebViewHelper(tableView: secondTableView, countClosure: {
            [weak self] in
            return self?.optionsCount ?? 0
        }, success: {
            [weak self] in
            guard let s = self else { return }
            s.secondUpdateFinished = true
            if s.firstUpdateFinished {
                s.firstTableView.reloadData()
            }
        })


    }
    
    fileprivate var orderedOptions : [String] = []
    fileprivate var optionsPermutation : [Int] = []
    fileprivate var positionForOptionInAttempt : [String : Int] = [:]
    
    var optionsCount: Int {
        return (self.attempt?.dataset as? MatchingDataset)?.pairs.count ?? 0
    }
    
    fileprivate func hasTagsInDataset(dataset: MatchingDataset) -> Bool {
        for pair in dataset.pairs {
            if TagDetectionUtil.isWebViewSupportNeeded(pair.first) || TagDetectionUtil.isWebViewSupportNeeded(pair.second) {
                return true
            }
        }
        return false
    }
    
    var latexSupportNeeded : Bool = false
    var countedNoLatexMaxHeight : Int = 0
    
    fileprivate func countNoLatexMaxHeight(dataset: MatchingDataset) -> Int {
        return dataset.pairs.map({
            pair in
            let width = self.view.bounds.width / 2
            return max(MatchingQuizTableViewCell.getHeightForText(text: pair.first, sortable: false, width: width), MatchingQuizTableViewCell.getHeightForText(text: pair.second, sortable: true, width: width))
        }).max() ?? 0
    }
    
    override func updateQuizAfterAttemptUpdate() {
        guard let dataset = attempt?.dataset as? MatchingDataset else {
            return
        }
        
        resetOptionsToAttempt()
        
        latexSupportNeeded = hasTagsInDataset(dataset: dataset)
        if latexSupportNeeded {
            updateHelper(webViewHelper: firstWebViewHelper, tableView: firstTableView, withReload: false)
            updateHelper(webViewHelper: secondWebViewHelper, tableView: secondTableView, withReload: false)

            self.firstTableView.reloadData()
            self.secondTableView.reloadData()
        } else {
            self.firstTableView.reloadData()
            self.secondTableView.reloadData()
            countedNoLatexMaxHeight = countNoLatexMaxHeight(dataset: dataset)
        }
    }
    
    //TODO: Something strange is happening here, check this
    fileprivate func resetOptionsToAttempt() {
        orderedOptions = []
        positionForOptionInAttempt = [:]
        optionsPermutation = []
        if let dataset = attempt?.dataset as? MatchingDataset {
            self.orderedOptions = dataset.secondValues
            for (index, option) in dataset.secondValues.enumerated() {
                optionsPermutation += [index]
                positionForOptionInAttempt[option] = index
            }
        }
    }
    
    override func updateQuizAfterSubmissionUpdate(reload: Bool = true) {
        if self.submission == nil {
            if reload {
                resetOptionsToAttempt()
            }
            self.secondTableView.isUserInteractionEnabled = true
        } else {
            if let dataset = attempt?.dataset as? MatchingDataset {
                var o = [String](repeating: "", count: dataset.pairs.count)
                if let r = submission?.reply as? MatchingReply {
                    print("attempt dataset -> \(dataset.pairs), \nsubmission ordering -> \(r.ordering)")
                    for (index, order) in r.ordering.enumerated() {
                        o[index] = dataset.secondValues[order]
                    }
                    optionsPermutation = r.ordering
                }
                orderedOptions = o
            }
            self.secondTableView.isUserInteractionEnabled = false
        }
        
        if latexSupportNeeded {
            self.firstTableView.reloadData()
            updateHelper(webViewHelper: firstWebViewHelper, tableView: firstTableView, withReload: false)
            updateHelper(webViewHelper: secondWebViewHelper, tableView: secondTableView, withReload: true)
        } else {
            self.firstTableView.reloadData()
            self.secondTableView.reloadData()
        }
    }
    
    var updatingWithReload = false
    
    fileprivate func updateHelper(webViewHelper: ControllerQuizWebViewHelper, tableView: UITableView, withReload: Bool) {
        webViewHelper.initChoicesHeights()
        if withReload {
            for row in 0 ..< self.tableView(tableView, numberOfRowsInSection: 0) {
                let c = tableView.cellForRow(at: IndexPath(row: row, section: 0))
                if let cell = c as? SortingQuizTableViewCell {
                    cell.optionWebView.reload()
                }
            }
            updatingWithReload = true
        } else {
            updatingWithReload = false
        }
        webViewHelper.updateChoicesHeights()
    }
        
    override func getReply() -> Reply {
        let r = MatchingReply(ordering: optionsPermutation)
        print(r.ordering)
        return r
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if latexSupportNeeded {
            secondTableViewHeight?.isActive = false
            updateHelper(webViewHelper: firstWebViewHelper, tableView: firstTableView, withReload: false)
            updateHelper(webViewHelper: secondWebViewHelper, tableView: secondTableView, withReload: false)

        } else {
            //TODO: Probably should re-count max height of the dataset
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    var maxHeight : Int {
        if latexSupportNeeded {
            return max(firstWebViewHelper.cellHeights.max() ?? 0, secondWebViewHelper.cellHeights.max() ?? 0)
        } else {
            return countedNoLatexMaxHeight
        }
    }
    
}

extension MatchingQuizViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        print("table \(tableView.tag) : HEIGHT for row at \(indexPath) called")
        return CGFloat(maxHeight)
    }
    
    @objc(tableView:canMoveRowAtIndexPath:) func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch tableView.tag {
        case 1: 
            return false
        case 2:
            return true
        default: 
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

extension MatchingQuizViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if attempt != nil {
            return 1
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return orderedOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("table \(tableView.tag) : CELL for row at \(indexPath) called")
        if latexSupportNeeded {

            let cell = tableView.dequeueReusableCell(withIdentifier: "SortingQuizTableViewCell", for: indexPath) as! SortingQuizTableViewCell
            
            if let dataset = attempt?.dataset as? MatchingDataset {
                switch tableView.tag {
                case 1:
                    firstWebViewHelper.cellHeightUpdateBlocks[(indexPath as NSIndexPath).row] = cell.setHTMLText(dataset.firstValues[(indexPath as NSIndexPath).row])
                case 2:
                    cell.sortable = true
                    secondWebViewHelper.cellHeightUpdateBlocks[(indexPath as NSIndexPath).row] = cell.setHTMLText(orderedOptions[(indexPath as NSIndexPath).row])
                default:
                    break
                }
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MatchingQuizTableViewCell", for: indexPath) as! MatchingQuizTableViewCell
            
            if let dataset = attempt?.dataset as? MatchingDataset {
                switch tableView.tag {
                case 1:
                    cell.setHTMLText(dataset.firstValues[(indexPath as NSIndexPath).row])
                case 2:
                    cell.setHTMLText(orderedOptions[(indexPath as NSIndexPath).row])
                default:
                    break
                }
            }
            
            return cell
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movingOption = orderedOptions[(sourceIndexPath as NSIndexPath).row]
        let movingIndex = optionsPermutation[sourceIndexPath.row]
        optionsPermutation.remove(at: sourceIndexPath.row)
        optionsPermutation.insert(movingIndex, at: destinationIndexPath.row)
        orderedOptions.remove(at: (sourceIndexPath as NSIndexPath).row)
        orderedOptions.insert(movingOption, at: (destinationIndexPath as NSIndexPath).row)
    }
}

