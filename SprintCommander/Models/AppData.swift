import Foundation

struct AppData: Codable {
    let timestamp: Date
    let projects: [Project]
    let kanbanTasks: [TaskItem]
    let velocityData: [VelocityPoint]
    let activities: [ActivityItem]
    let teamMembers: [TeamMember]
    let burndownIdeal: [Double]
    let burndownActual: [Double]
}
