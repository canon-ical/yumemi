//// Entry declarations; deployment values are resolved by the adapter.
pub type Admit { Anonymous Authenticated }
pub type Services { ReadOnly All }
pub type Subjects(subject) { Subjects(List(subject)) AnySubject }
pub type Entry(subject, host) {
  Http(name: String, hosts: List(host), admit: Admit, subject: Subjects(subject), services: Services)
}
