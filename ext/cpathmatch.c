#include <ruby.h>
#include <ctype.h>

/**
 * The path separator on the current system, according to File::SEPARATOR. It's
 * not truly a constant, but it should be defined exactly once when
 * initializing this extension.
 */
static char kPathSep;

/**
 * Everything we need to know about a path and the query we're trying to match
 * against it in one place, in C land. The max_score_per_char depends on both
 * the path length and the query length.
 */
typedef struct
{
  const char *query;
  long query_len;
  const char *path;
  long path_len;
  double max_score_per_char;
} pathmatch_t;

/**
 * Finds the positions of (up to) the next two path characters that match the
 * current query character, storing the results in the passed in p_pos and
 * p_pos_next. This is helpful because, each time we find a match, we also
 * compute the score we'd get if we didn't take the match (i.e., if we looked
 * for the _next_ path character that matches).
 */
void find_next_2_matches(
    const pathmatch_t *pm, char qc, long p_beg, long *p_pos, long *p_pos_next);

/**
 * Computes the diminishing factor for a path character given the previous
 * character and how far away it is from the last matched path character.
 */
double compute_factor(
    char pc, char pc_prev, long distance);

/**
 * Computes the score for a path and query, starting from specified positions
 * within each. Calls itself recursively each time it finds a path character
 * that matches a query character and there is a path character farther along
 * that we could match instead. Returns the best score found among all of the
 * speculative paths.
 */
double
compute_score(
    const pathmatch_t *pm,
    long q_beg,
    long p_beg,
    long p_pos_last)
{
  double score = 0.0, best_score = 0.0, score_alt, pc_score;
  long q_pos, p_pos, p_pos_next, distance;
  char qc, pc, pc_prev;
  for (q_pos = q_beg; q_pos < pm->query_len; q_pos++) {
    qc = pm->query[q_pos];
    find_next_2_matches(pm, qc, p_beg, &p_pos, &p_pos_next);
    if (p_pos == -1) {
      return 0.0;
    }
    pc = pm->path[p_pos];
    pc_score = pm->max_score_per_char;
    distance = p_pos - p_pos_last;
    if (distance > 1 && !(pc == kPathSep || qc == '.')) {
      pc_prev = pm->path[p_pos - 1];
      pc_score *= compute_factor(pc, pc_prev, distance);
    }
    if (p_pos_next != -1) {
      score_alt = score + compute_score(pm, q_pos, p_pos_next, p_pos_last);
      if (score_alt > best_score) {
        best_score = score_alt;
      }
    }
    score += pc_score;
    p_pos_last = p_pos;
    p_beg = p_pos + 1;
  }
  return score > best_score ? score : best_score;
}

void
find_next_2_matches(
    const pathmatch_t *pm,
    char qc,
    long p_beg,
    long *p_pos,
    long *p_pos_next)
{
  const char *pc, *p_end = pm->path + pm->path_len;
  *p_pos = -1;
  for (pc = pm->path + p_beg; pc < p_end; pc++) {
    if (qc == tolower(*pc)) {
      *p_pos = pc - pm->path;
      break;
    }
  }
  *p_pos_next = -1;
  for (pc = pc + 1; pc < p_end; pc++) {
    if (qc == tolower(*pc)) {
      *p_pos_next = pc - pm->path;
      break;
    }
  }
}

double
compute_factor(
    char pc,
    char pc_prev,
    long distance)
{
  if (pc_prev == kPathSep) {
    return 0.9;
  } else if (pc_prev == '-' || pc_prev == '_' || pc_prev == ' ' ||
      (pc_prev >= '0' && pc_prev <= '9')) {
    return 0.8;
  } else if (pc_prev >= 'a' && pc_prev <= 'z'&& pc >= 'A' && pc <= 'Z') {
    return 0.8;
  } else if (pc_prev == '.') {
    return 0.7;
  } else {
    return (1.0 / distance) * 0.75;
  }
}

/**
 * The CPathMatch.initialize method. It fetches everything it needs in order to
 * compute a match score from the passed path (a String) and Query, then passes
 * it off to compute_score().
 */
VALUE
CPathMatch_initialize(VALUE self, VALUE rb_path, VALUE rb_oQuery)
{
  VALUE rb_query = rb_funcall(rb_oQuery, rb_intern("query"), 0);
  char *query = StringValuePtr(rb_query);
  long query_len = RSTRING_LEN(rb_query);

  char *path = StringValuePtr(rb_path);
  long path_len = RSTRING_LEN(rb_path);

  pathmatch_t pm;
  pm.query = query;
  pm.query_len = query_len;
  pm.path = path;
  pm.path_len = path_len;
  pm.max_score_per_char = (1.0 / path_len + 1.0 / query_len) / 2.0;

  double score = compute_score(&pm,
      /* q_beg */ 0, /* p_beg */ 0, /* p_pos_last */ -1);

  rb_iv_set(self, "@path", rb_path);
  rb_iv_set(self, "@score", DBL2NUM(score));

  return self;
}

/**
 * Initialize the extension:
 *
 * - Add a CPathMatch class to the Matcher module with the same interface and
 *   behavior as PathMatch, but with the expensive match logic done in C.
 * - Set up kPathSep from File::SEPARATOR.
 */
void
Init_cpathmatch()
{
  VALUE cMatcher = rb_define_class("Matcher", rb_cObject);
  VALUE cCPathMatch = rb_define_class_under(
      cMatcher, "CPathMatch", rb_cObject);

  rb_define_method(cCPathMatch,
      "initialize", CPathMatch_initialize, /* argc */ 2);

  rb_define_attr(cCPathMatch, "path",  /* read */ 1, /* write */ 0);
  rb_define_attr(cCPathMatch, "score", /* read */ 1, /* write */ 0);

  // Get the path separator character from File::SEPARATOR and store it
  // statically.
  VALUE rb_path_sep = rb_const_get_at(rb_cFile, rb_intern("SEPARATOR"));
  kPathSep = *StringValueCStr(rb_path_sep);
}
