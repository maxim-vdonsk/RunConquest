import HealthKit
import Observation

// MARK: - HealthKit Manager

@Observable
@MainActor
class HealthKitManager {
    private let store = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var heartRateQuery: HKObserverQuery?
    private var pollTimer: Timer?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isAuthorized = false

    var heartRate: Int = 0
    var calories: Double = 0

    private var workoutStartDate: Date?

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount)
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKWorkoutType.workoutType()
        ]
        do {
            try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Workout Lifecycle

    func startWorkout() {
        guard isAvailable else { return }
        workoutStartDate = Date()
        calories = 0
        heartRate = 0

        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        workoutBuilder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }

        startHeartRatePolling()
    }

    func stopWorkout(distance: Double, completion: @escaping (Int) -> Void) {
        stopHeartRatePolling()
        guard let builder = workoutBuilder, let startDate = workoutStartDate else {
            completion(0)
            return
        }
        let endDate = Date()

        let distanceSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: HKQuantity(unit: .meter(), doubleValue: distance),
            start: startDate, end: endDate
        )
        let calSample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            start: startDate, end: endDate
        )

        builder.add([distanceSample, calSample]) { _, _ in
            builder.endCollection(withEnd: endDate) { _, _ in
                builder.finishWorkout { _, _ in }
            }
        }

        let elapsed = Int(endDate.timeIntervalSince(startDate))
        workoutBuilder = nil
        workoutStartDate = nil
        completion(elapsed)
    }

    // MARK: - Heart Rate Polling

    private func startHeartRatePolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.queryLatestHeartRate()
                self?.queryCalories()
            }
        }
        queryLatestHeartRate()
    }

    private func stopHeartRatePolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let query = heartRateQuery { store.stop(query) }
        heartRateQuery = nil
    }

    private func queryLatestHeartRate() {
        let type = HKQuantityType(.heartRate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            Task { @MainActor [weak self] in self?.heartRate = bpm }
        }
        store.execute(query)
    }

    private func queryCalories() {
        guard let start = workoutStartDate else { return }
        let type = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, stats, _ in
            let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            Task { @MainActor [weak self] in self?.calories = kcal }
        }
        store.execute(query)
    }
}
