import { useState, useCallback, useRef } from 'react';
import { searchQuran } from '../services/SearchService';
import type { SearchOptions } from '../services/SearchService';
import type { SearchResult } from '../types/quran';

export function useSearch() {
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const search = useCallback(async (opts: SearchOptions) => {
    setQuery(opts.query);
    if (!opts.query.trim()) {
      setResults([]);
      return;
    }

    setLoading(true);
    try {
      const res = await searchQuran(opts);
      setResults(res);
    } catch (e) {
      console.error('Search failed:', e);
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  const debouncedSearch = useCallback(
    (opts: SearchOptions) => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => search(opts), 300);
    },
    [search]
  );

  const clear = useCallback(() => {
    setQuery('');
    setResults([]);
  }, []);

  return { results, loading, query, search: debouncedSearch, clear };
}
