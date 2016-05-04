//
//  LinearRegression.swift
//  MultilinearMath
//
//  Created by Vincent Herrmann on 25.04.16.
//  Copyright © 2016 Vincent Herrmann. All rights reserved.
//

import Foundation

public func linearRegression(x x: Tensor<Float>, y: Tensor<Float>) -> Tensor<Float> {
    
    let example = TensorIndex.a
    let feature = TensorIndex.b
    
    let exampleCount = x.modeSizes[0]
    let featureCount = x.modeSizes[1]
    
    var samples = Tensor<Float>(modeSizes: [exampleCount, featureCount + 1], repeatedValue: 1)
    samples[all, 1...featureCount] = x
    
    // formula: w = (X^T * X)^-1 * X * y
    let sampleCovariance = samples[example, feature] * samples[example, .k]
    let inverseCovariance = inverse(sampleCovariance, rowMode: 0, columnMode: 1)
    let parameters = inverseCovariance[feature, .k] * samples[example, .k] * y[example]

    return parameters
}

public func linearRegressionGD(x x: Tensor<Float>, y: Tensor<Float>) -> (parameters: Tensor<Float>, mean: Tensor<Float>, deviation: Tensor<Float>) {
    
    let example = TensorIndex.a
    let feature = TensorIndex.b
    
    let exampleCount = x.modeSizes[0]
    let featureCount = x.modeSizes[1]
    
    let xNorm = normalize(x, overModes: [0])
    
    var samples = Tensor<Float>(modeSizes: [exampleCount, featureCount + 1], repeatedValue: 1)
    samples[all, 1...featureCount] = xNorm.normalizedTensor
    var parameters = Tensor<Float>(modeSizes: [featureCount + 1], repeatedValue: 0)
    
    let costFunction = {(theta: Tensor<Float>) -> Float in
        let hypothesis = theta[feature] * samples[example, feature]
        let distance = hypothesis[example] - y[example]
        //let cost = (0.5/Float(exampleCount)) * vectorSummation(vectorSquaring(distance.values))
        let cost = (0.5/Float(exampleCount)) * (distance[example] * distance[example])
        return cost.values[0]
    }
    
    let gradientFunction = {(theta: Tensor<Float>) -> Tensor<Float> in
        let gradient = (1/Float(exampleCount)) * ((theta[feature] * samples[example, feature]) - y[example]) * samples[example, feature]
        return gradient
    }
    
    gradientDescent(&parameters, costFunction: costFunction, gradientFunction: gradientFunction, updateRate: 0.1)
    
    return (parameters, xNorm.mean, xNorm.standardDeviation)
}

public func gradientDescent(inout parameters: Tensor<Float>, costFunction: (Tensor<Float> -> Float), gradientFunction: Tensor<Float> -> Tensor<Float>, updateRate: Float) {
    
    var cost = FLT_MAX
    
    for _ in 0..<1000 {
        let currentCost = costFunction(parameters)
        print("gradient descent - current cost: \(currentCost)")
        
        if(abs(cost - currentCost) < 0.001) {
            break
        }
        
        cost = currentCost
        
        parameters = parameters[TensorIndex.a] - (updateRate * gradientFunction(parameters))[TensorIndex.a]
    }
}