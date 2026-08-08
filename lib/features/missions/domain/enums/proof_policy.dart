/// Whether a mission expects photo/text proof. Proof *upload* itself is out
/// of scope for this phase — this only records the catalog's declared
/// policy so the UI can show "Proof required" consistently later.
enum ProofPolicy { none, optional, required }
