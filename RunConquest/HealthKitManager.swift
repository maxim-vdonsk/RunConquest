import HealthKit
import Observation

// MARK: - HealthKit Manager

@Observable
@MainActor
class HealthKitManager {
    private let store = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
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

    // MARK: - Heart Rate Live Subscription

    private func startHeartRatePolling() {
        guard let start = workoutStartDate else { return }

        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)

        // HKAnchoredObjectQuery — живая подписка: updateHandler срабатывает
        // каждый раз, когда Watch пишет новый сэмпл пульса в HealthKit.
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor [weak self] in self?.applyHeartRateSamples(samples) }
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor [weak self] in self?.applyHeartRateSamples(samples) }
        }
        store.execute(query)
        heartRateQuery = query

        // Калории обновляем таймером — они не критичны для реалтайма
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.queryCalories() }
        }
    }

    private func applyHeartRateSamples(_ samples: [HKSample]?) {
        guard let sample = (samples as? [HKQuantitySample])?
            .sorted(by: { $0.startDate < $1.startDate })
            .last else { return }
        let bpm = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
        Task { @MainActor [weak self] in self?.heartRate = bpm }
    }

    private func stopHeartRatePolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let query = heartRateQuery { store.stop(query) }
        heartRateQuery = nil
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
