import json


class RAGService:
    def __init__(self, persist_dir: str):
        self.persist_dir = persist_dir
        self._client = None
        self._embedding_fn = None
        self._initialized = False

    def _ensure_initialized(self):
        if self._initialized:
            return
        try:
            import chromadb
            from chromadb.utils import embedding_functions

            self._client = chromadb.PersistentClient(path=self.persist_dir)
            self._embedding_fn = (
                embedding_functions.SentenceTransformerEmbeddingFunction(
                    model_name="sentence-transformers/all-MiniLM-L6-v2"
                )
            )
            self._initialized = True
        except Exception as e:
            raise RuntimeError(f"Failed to initialize ChromaDB: {e}")

    def get_or_create_collection(self, collection_id: str):
        self._ensure_initialized()
        return self._client.get_or_create_collection(
            name=collection_id,
            embedding_function=self._embedding_fn,
        )

    def build_documents(
        self, schema: dict, samples: list, stats: dict
    ) -> list[str]:
        schema_lines = ["Dataset schema:"]
        for col in schema.get("columns", []):
            line = f"  - {col['name']} ({col['dtype']})"
            if col.get("nullable"):
                line += " [nullable]"
            if "unique_values" in col:
                line += f" values: {col['unique_values']}"
            schema_lines.append(line)
        schema_doc = "\n".join(schema_lines)

        sample_lines = ["Sample data rows:"]
        for i, row in enumerate(samples[:5]):
            sample_lines.append(f"  Row {i + 1}: {json.dumps(row, default=str)}")
        sample_doc = "\n".join(sample_lines)

        stats_lines = ["Statistical summary:"]
        meta = stats.get("_meta", {})
        if meta:
            stats_lines.append(
                f"  Total rows: {meta.get('total_rows')}, "
                f"Total columns: {meta.get('total_columns')}"
            )
        for col, col_stats in stats.items():
            if col == "_meta" or not isinstance(col_stats, dict):
                continue
            if "mean" in col_stats or "count" in col_stats:
                parts = []
                for k in ["count", "mean", "min", "max", "std"]:
                    if col_stats.get(k) is not None:
                        parts.append(f"{k}={col_stats[k]:.2f}" if isinstance(col_stats[k], float) else f"{k}={col_stats[k]}")
                stats_lines.append(f"  {col}: {', '.join(parts)}")
        stats_doc = "\n".join(stats_lines)

        return [schema_doc, sample_doc, stats_doc]

    def index_dataset(
        self, collection_id: str, schema: dict, samples: list, stats: dict
    ):
        self._ensure_initialized()
        collection = self.get_or_create_collection(collection_id)
        documents = self.build_documents(schema, samples, stats)
        ids = ["schema", "samples", "stats"]
        existing = collection.get(ids=ids)
        if existing["ids"]:
            collection.delete(ids=existing["ids"])
        collection.add(documents=documents, ids=ids)

    def retrieve_context(
        self, collection_id: str, query: str, n_results: int = 3
    ) -> list[str]:
        self._ensure_initialized()
        try:
            collection = self.get_or_create_collection(collection_id)
            results = collection.query(query_texts=[query], n_results=n_results)
            return results["documents"][0] if results["documents"] else []
        except Exception:
            return []

    def delete_collection(self, collection_id: str):
        self._ensure_initialized()
        try:
            self._client.delete_collection(collection_id)
        except Exception:
            pass
