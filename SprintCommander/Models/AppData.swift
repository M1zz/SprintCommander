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
    let sprints: [Sprint]

    init(timestamp: Date, projects: [Project], kanbanTasks: [TaskItem], velocityData: [VelocityPoint], activities: [ActivityItem], teamMembers: [TeamMember], burndownIdeal: [Double], burndownActual: [Double], sprints: [Sprint] = []) {
        self.timestamp = timestamp
        self.projects = projects
        self.kanbanTasks = kanbanTasks
        self.velocityData = velocityData
        self.activities = activities
        self.teamMembers = teamMembers
        self.burndownIdeal = burndownIdeal
        self.burndownActual = burndownActual
        self.sprints = sprints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        projects = try c.decode([Project].self, forKey: .projects)
        kanbanTasks = try c.decode([TaskItem].self, forKey: .kanbanTasks)
        velocityData = try c.decode([VelocityPoint].self, forKey: .velocityData)
        activities = try c.decode([ActivityItem].self, forKey: .activities)
        teamMembers = try c.decode([TeamMember].self, forKey: .teamMembers)
        burndownIdeal = try c.decode([Double].self, forKey: .burndownIdeal)
        burndownActual = try c.decode([Double].self, forKey: .burndownActual)
        sprints = try c.decodeIfPresent([Sprint].self, forKey: .sprints) ?? []
    }
}
