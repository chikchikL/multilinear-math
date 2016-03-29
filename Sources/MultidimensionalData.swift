//
//  MultidimensionalData.swift
//  MultilinearMath
//
//  Created by Vincent Herrmann on 27.03.16.
//  Copyright © 2016 Vincent Herrmann. All rights reserved.
//

import Foundation

/// Multidimensional collection of elements of a certain type. The elements are stored in a flat array but accessed with multidimensional Integer indices.
public protocol MultidimensionalData {
    /// the kind of value that is stored
    associatedtype Element
    
    /// the size in of mode
    var modeSizes: [Int] {get set}
    /// the raw values in a flat array
    var values: [Element] {get set}
    
    init(modeSizes: [Int], values: [Element])
    
    /// Will get called everytime the order of the modes changes. If there are any changes to be done, implement them here, else do nothing
    mutating func newModeOrder(newToOld: [Int])
}

public extension MultidimensionalData {
    /// number of modes
    var modeCount: Int {
        get {
            return modeSizes.count
        }
    }
    
    /// total number of elements
    var elementCount: Int {
        get {
            //multiply all modeSizes
            return modeSizes.reduce(1, combine: {$0*$1})
        }
    }
    
    /// simply Array(0..<modeCount)
    var modeArray: [Int] {
        get {
            return Array(0..<modeCount)
        }
    }
    
    init(modeSizes: [Int], repeatedValue: Element) {
        let count = modeSizes.reduce(1, combine: {$0*$1})
        self.init(modeSizes: modeSizes, values: [Element](count: count, repeatedValue: repeatedValue))
    }
    
    /// Convert a nested multidimensional index into a flat index
    /// - Returns: The flattened index
    func flatIndex(index: [Int]) -> Int {
        
        if(modeCount == 0) {
            return 0
        }
        
        //converts the multidimensional index into the index of the flattened data array
        assert(index.count == modeCount, "wrong number of modes in \(index), \(modeCount) indices needed")
        
        var thisFlatIndex = 0
        for d in 0..<modeCount {
            thisFlatIndex = thisFlatIndex * modeSizes[d] + index[d]
        }
        
        return thisFlatIndex
    }
    
    /// Convert a flat index into a multidimensional nested index
    /// - Returns: The nested index
    func nestedIndex(flatIndex: Int) -> [Int] {
        //converts a flat index into a multidimensional index
        var currentFlatIndex = flatIndex
        var index: [Int] = [Int](count: max(modeCount, 1), repeatedValue: 0)
        
        for d in (0..<modeCount).reverse() {
            let thisIndex = currentFlatIndex % modeSizes[d]
            index[d] = thisIndex
            currentFlatIndex = (currentFlatIndex-thisIndex) / modeSizes[d]
        }
        
        return index
    }
    
    /// - Returns: The given flat index moved by a given number of steps in the given mode
    func moveFlatIndex(index: Int, by: Int, mode: Int) -> Int {
        var multiIndex = [Int](count: modeCount, repeatedValue: 0)
        multiIndex[mode] = by
        
        return index + flatIndex(multiIndex)
    }
    
    /// - Returns: All flat indices lying in the given multidimensional range
    func indicesInRange(ranges: [Range<Int>]) -> [Int] {
        //create indices array with start index (corner with the lowest index)
        var indices: [Int] = [flatIndex(ranges.map({return $0.first!}))]
        
        for m in (0..<modeCount).reverse() { //for each mode (start with last to have right order)
            for i in 0..<indices.count { //for every index currently in the array
                for r in 1..<ranges[m].count { //for every number in the specified range
                    //move indicex by this number in the current mode and add them to the array
                    indices.append(moveFlatIndex(indices[i], by: r, mode: m))
                }
            }
        }
        return indices
    }
    
    func getWithFlatIndex(flatIndex: Int) -> Element {
        return values[flatIndex]
    }
    mutating func set(newElement: Element, atFlatIndex: Int) {
        values[atFlatIndex] = newElement
    }
    
    func getSlice(modeSubscripts: [DataSliceSubscript]) -> Self {
        let subscripts = completeDataSliceSubscripts(modeSubscripts)
        
        let newSizes = subscripts.map({$0.sliceSize}).filter({$0 > 1})
        var newData = Self(modeSizes: newSizes, repeatedValue: values[0])
        
        // index in this data object
        var currentDataIndex = [Int](count: modeCount, repeatedValue: 0)
        // index in newData
        var currentSliceIndex = [Int](count: newData.modeCount, repeatedValue: 0)
        
        subscripts[0].recurseCopyFrom(self, to: &newData, currentDataIndex: &currentDataIndex, currentSliceIndex: &currentSliceIndex, currentDataMode: 0, currentSliceMode: 0, sliceSubscripts: subscripts)
        
        return newData
    }
    
    mutating func setSlice(slice: Self, modeSubscripts: [DataSliceSubscript]) {
        let subscripts = completeDataSliceSubscripts(modeSubscripts)
        
        // index in this data object
        var currentDataIndex = [Int](count: modeCount, repeatedValue: 0)
        // index in newData
        var currentSliceIndex = [Int](count: slice.modeCount, repeatedValue: 0)
        
        subscripts[0].recurseCopyTo(&self, from: slice, currentDataIndex: &currentDataIndex, currentSliceIndex: &currentSliceIndex, currentDataMode: 0, currentSliceMode: 0, sliceSubscripts: subscripts)
    }
    
    ///Replace subscripts of type AllIndices with the complete range, same with missing subscripts
    private func completeDataSliceSubscripts(subscripts: [DataSliceSubscript]) -> [DataSliceSubscript] {
        var newSubscripts = subscripts
        for m in 0..<modeCount {
            if(m >= subscripts.count) {
                newSubscripts.append(0..<modeSizes[m])
            }
            
            if newSubscripts[m] is AllIndices {
                newSubscripts[m] = 0..<modeSizes[m]
            }
        }
        return newSubscripts
    }
    
    ///Reorder the modes of this item
    /// - Parameter newToOld: Mapping from the new mode indices to the old ones
    /// - Returns: A copy of this item with the same values but reordered modes
    func reorderModes(newToOld: [Int]) -> Self {
        if(newToOld == Array(0..<modeCount) || newToOld.count == 0) {
            return self
        }
        
        //calculate mapping from modes in the original data to modes the new data
        let oldToNew = (0..<modeCount).map({(oldMode: Int) -> Int in
            guard let i = newToOld.indexOf(oldMode) else {
                assert(true, "mode \(oldMode) not found in mapping newToOld \(newToOld)")
                return 0
            }
            return i
        })
        
        var lastChangedMode = -1
        for d in 0..<modeCount {
            if(newToOld[d] != d) {
                lastChangedMode = d
            }
        }
        
        var newData = Self(modeSizes: newToOld.map({modeSizes[$0]}), repeatedValue: values[0])
        
        let copyLength = modeSizes[lastChangedMode+1..<modeCount].reduce(1, combine: {$0*$1})
        
        var currentOldIndex = [Int](count: modeCount, repeatedValue: 0)
        var currentNewIndex = [Int](count: modeCount, repeatedValue: 0)
        
        var copyRecursion: (Int -> Void)!
        
        copyRecursion = {(oldMode: Int) -> () in
            if(oldMode < lastChangedMode) {
                for i in 0..<self.modeSizes[oldMode] {
                    currentOldIndex[oldMode] = i
                    currentNewIndex[oldToNew[oldMode]] = i
                    copyRecursion(oldMode + 1)
                }
            } else {
                for i in 0..<self.modeSizes[oldMode] {
                    currentOldIndex[oldMode] = i
                    currentNewIndex[oldToNew[oldMode]] = i
                    
                    let oldFlatIndex = self.flatIndex(currentOldIndex)
                    let newFlatIndex = newData.flatIndex(currentNewIndex)
                    newData.values[newFlatIndex..<newFlatIndex+copyLength] = self.values[oldFlatIndex..<oldFlatIndex+copyLength]
                }
            }
        }
        
        copyRecursion(0)
        
        newData.newModeOrder(newToOld)
        
        return newData
    }
    
    /// - Returns: The data as matrix unfolded along the given mode. If allowTranspose is true, the returned matrix could be transposed, if that was computationally more efficient
    public func matrixWithMode(mode: Int, allowTranspose: Bool = true) -> (matrix: [Element], size: MatrixSize, transpose: Bool) {
        assert(mode < modeCount, "mode \(mode) not available in tensor with \(modeCount) modes")
        
        let remainingModes = (0..<modeCount).filter({$0 != mode})
        let defaultOrder = [mode] + remainingModes
        let rows = modeSizes[mode]
        let columns = remainingModes.map({modeSizes[$0]}).reduce(1, combine: {$0 * $1})
        
        if(allowTranspose) {
            let complexityDefault = reorderComplexity(defaultOrder)
            let transposeOrder = remainingModes + [mode]
            let complexityTranspose = reorderComplexity(transposeOrder)
            
            if(complexityTranspose < complexityDefault) {
                let size = MatrixSize(rows: columns, columns: rows)
                return(reorderModes(transposeOrder).values, size, true)
            }
        }
        
        let size = MatrixSize(rows: rows, columns: columns)
        return(reorderModes(defaultOrder).values, size, false)
    }
    
    /// - Returns: The number of seperate copy streaks that would be necessary for this reordering of modes
    func reorderComplexity(newToOld: [Int]) -> Int {
        let hasToChange = Array(0..<modeCount).combineWith(newToOld, combineFunction: {$0 != $1})
        
        if let lastMode = Array(hasToChange.reverse()).indexOf({$0}) { //last mode that has to change
            return modeSizes[0...(modeCount-1-lastMode)].reduce(1, combine: {$0*$1})
        } else {
            return 0
        }
    }
    
    public subscript(flatIndex: Int) -> Element {
        get {
            return getWithFlatIndex(flatIndex)
        }
        set(newValue) {
            set(newValue, atFlatIndex: flatIndex)
        }
    }
    public subscript(nestedIndex: [Int]) -> Element {
        get {
            return getWithFlatIndex(flatIndex(nestedIndex))
        }
        set(newValue) {
            set(newValue, atFlatIndex: flatIndex(nestedIndex))
        }
    }
    public subscript(nestedIndex: Int...) -> Element {
        get {
            return getWithFlatIndex(flatIndex(nestedIndex))
        }
        set(newValue) {
            set(newValue, atFlatIndex: flatIndex(nestedIndex))
        }
    }
    public subscript(slice modeIndices: [DataSliceSubscript]) -> Self {
        get {
            return getSlice(modeIndices)
        }
        
        set(newData) {
            setSlice(newData, modeSubscripts: modeIndices)
        }
    }
    public subscript(modeIndices: DataSliceSubscript...) -> Self {
        get {
            return getSlice(modeIndices)
        }
        set(newData) {
            setSlice(newData, modeSubscripts: modeIndices)
        }
    }
    
    /// Perform a given action for each index of a given subset of modes. The updating of the indices is done by another given function.
    ///
    /// - Parameter action: The action to perform for each index combination of the given modes.
    /// - Parameter indexUpdate: Function that will be called every time the index changes with the following arguments: <br>
    /// `indexNumber:` Index of `currentMode` in the `forModes` array. <br>
    /// `currentMode:`  The mode from the `forModes` where the index changed. <br>
    /// `i:` The updated index of the `currentMode`.
    ///- Parameter forModes: The subset of modes on which the `action` will be performed.
    public func perform(action: (currentIndex: [DataSliceSubscript]) -> (), indexUpdate: (indexNumber: Int, currentMode: Int, i: Int) -> () = {_,_,_ in}, forModes: [Int]) {
        
        var currentIndex: [DataSliceSubscript] = modeSizes.map({0..<$0})
        
        func actionRecurse(thisIndexNumber: Int) {
            if(thisIndexNumber < forModes.count) {
                let thisCurrentMode = forModes[thisIndexNumber]
                for i in 0..<modeSizes[thisCurrentMode] {
                    currentIndex[thisCurrentMode] = i...i
                    indexUpdate(indexNumber: thisIndexNumber, currentMode: thisCurrentMode, i: i)
                    actionRecurse(thisIndexNumber + 1)
                }
            } else {
                action(currentIndex: currentIndex)
            }
        }
        
        if(forModes.count == 0) {
            action(currentIndex: currentIndex)
        } else {
            actionRecurse(0)
        }
    }
    
    /// - Returns: The flat start indices in the value array of all continuous vectors (in the last mode) that constitute the given multidimensional range
    private func startIndicesOfContinuousVectorsForRange(ranges: [Range<Int>]) -> [Int] {
        //the ranges of all modes except the last (where the continuous vectors are)
        var firstModesRanges = Array(ranges[0..<modeCount-1])
        firstModesRanges.append(ranges.last!.startIndex...ranges.last!.startIndex)
        //the flat indices of the first elements in the last mode that lie in the firstModesRanges
        let indexPositions = indicesInRange(Array(firstModesRanges))
        //add the start offset of the last mode to each index
        return indexPositions//.map({return $0 + ranges.last!.first!})
    }
}

/// Combine two `MultidimensionalData` items with the given `combineFunction`
///
/// - Parameter a: The first `MultidimensionalData` item
/// - Parameter outerModesA: The modes of `a` for which the `combineFunction` will be called
/// - Parameter b: The second `MultidimensionalData` item
/// - Parameter outerModesA: The modes of `b` for which the `combineFunction` will be called
/// - Parameter indexUpdate: This function will be called before each `combineFunction` call. Default is an empty function. <br> *Parameters*: <br>
/// `indexNumber:` The number of the `currentMode`, considering only the outerModes of both `a` and `b` together. <br>
/// `currentMode:` The index of the `currentMode` in the `modeArray` of either `a` or `b`. <br>
/// `currentModeIsA:` If true, the `currentMode` is from `a`, else from `b` <br>
/// `i`: The new index of the `currentMode`
/// - Parameter combineFunction: The action to combine `a` and `b`. <br> *Parateters*: <br>
/// `currentIndexA:` The index for `a` that gives the relevant slice for this particular call. <br>
/// `currentIndexB:` The index for `b` that gives the relevant slice for this particular call.
public func combine<T: MultidimensionalData>(a a: T, outerModesA: [Int], b: T, outerModesB: [Int], indexUpdate: (indexNumber: Int, currentMode: Int, currentModeIsA: Bool, i: Int) -> () = {_,_,_,_ in}, combineFunction: (currentIndexA: [DataSliceSubscript], currentIndexB: [DataSliceSubscript]) -> ()) {
    
    let outerModeCount = outerModesA.count + outerModesB.count
    var currentIndexA: [DataSliceSubscript] = a.modeSizes.map({0..<$0})
    var currentIndexB: [DataSliceSubscript] = b.modeSizes.map({0..<$0})
    
    func actionRecurse(indexNumber: Int) {
        if(indexNumber < outerModeCount) {
            if(indexNumber < outerModesA.count) {
                let currentMode = outerModesA[indexNumber]
                for i in 0..<a.modeSizes[currentMode] {
                    currentIndexA[currentMode] = i...i
                    indexUpdate(indexNumber: indexNumber, currentMode: currentMode, currentModeIsA: true, i: i)
                    actionRecurse(indexNumber + 1)
                }
            } else {
                let currentMode = outerModesB[indexNumber - outerModesA.count]
                for i in 0..<b.modeSizes[currentMode] {
                    currentIndexB[currentMode] = i...i
                    indexUpdate(indexNumber: indexNumber, currentMode: currentMode, currentModeIsA: false, i: i)
                    actionRecurse(indexNumber + 1)
                }
            }
        } else {
            combineFunction(currentIndexA: currentIndexA, currentIndexB: currentIndexB)
        }
    }
    
    if(outerModeCount == 0) {
        combineFunction(currentIndexA: currentIndexA, currentIndexB: currentIndexB)
    } else {
        actionRecurse(0)
    }
}