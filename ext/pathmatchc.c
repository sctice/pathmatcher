#include <ruby.h>

#include <ctype.h>   // tolower()
#include <strings.h> // bzero()

#define POS_MAP_SIZE 256

/**
 * The path separator on the current system, according to File::SEPARATOR. It's
 * not truly a constant, but it should be defined exactly once when
 * initializing this extension.
 */
static char kPathSep;

/**
 * A cache structure to remember the positions in the target path at which a
 * particular character occurs and to allow finding in constant time the next
 * position given any current position.
 */
typedef struct
{
  unsigned char initialized;
  long *pos;
} pos_list_t;

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
  pos_list_t qc_pos_map[POS_MAP_SIZE];
} pathmatch_t;


/* Begin prototypes */

long find_next_match(
    pathmatch_t *pm, char qc, long p_beg);

void init_pos_list(
    pos_list_t *pl, pathmatch_t *pm, char qc);

double compute_factor(
    char pc, char pc_prev, long distance);

/* End prototypes */

/**
 * Computes the score for a path and query, starting from specified positions
 * within each. Calls itself recursively each time it finds a path character
 * that matches a query character and there is a path character farther along
 * that we could match instead. Returns the best score found among all of the
 * speculative paths.
 */
double
compute_score(
    pathmatch_t *pm,
    long q_beg,
    long p_beg,
    long p_pos_last)
{
  double score = 0.0, best_score = 0.0, score_alt, pc_score;
  long q_pos, p_pos, p_pos_next, distance;
  char qc, pc, pc_prev;
  for (q_pos = q_beg; q_pos < pm->query_len; q_pos++) {
    qc = pm->query[q_pos];
    p_pos = find_next_match(pm, qc, p_beg);
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
    p_pos_next = find_next_match(pm, qc, p_pos + 1);
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

/**
 * Finds the positions of (up to) the next two path characters that match the
 * current query character, storing the results in the passed in p_pos and
 * p_pos_next. This is helpful because, each time we find a match, we also
 * compute the score we'd get if we didn't take the match (i.e., if we looked
 * for the _next_ path character that matches).
 */
long
find_next_match(
    pathmatch_t *pm,
    char qc,
    long p_beg)
{
  pos_list_t *pl;
  if (p_beg < pm->path_len) {
    pl = pm->qc_pos_map + (unsigned char)qc;
    if (!pl->initialized) {
      init_pos_list(pl, pm, qc);
    }
    return pl->pos[p_beg];
  }
  return -1;
}

/**
 * Allocates an array the same size as the target path, then fills each entry
 * e_i with the position of the next qc match, starting from position i. This
 * is accomplished in one scan over the path by starting at the end and working
 * backward, filling the current entry with the last position a match was seen
 * at. If there is no previous match, then the entry is set to -1.
 */
void
init_pos_list(
    pos_list_t *pl,
    pathmatch_t *pm,
    char qc)
{
  long i = pm->path_len - 1, last = -1;
  const char *pc = pm->path + i;
  pl->pos = malloc(pm->path_len * sizeof(long));
  pl->initialized = 1;
  for (; pc >= pm->path; pc--, i--) {
    if (qc != tolower(*pc)) {
      pl->pos[i] = last;
    } else {
      pl->pos[i] = i;
      last = i;
    }
  }
}

/**
 * Computes the diminishing factor for a path character given the previous
 * character and how far away it is from the last matched path character.
 */
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
 * The PathMatchC.initialize method. It fetches everything it needs in order to
 * compute a match score from the passed path (a String) and Query, then passes
 * it off to compute_score().
 */
VALUE
PathMatchC_initialize(VALUE self, VALUE rb_path, VALUE rb_oQuery)
{
  VALUE rb_query = rb_funcall(rb_oQuery, rb_intern("query"), 0);
  char *query = StringValuePtr(rb_query);
  long query_len = RSTRING_LEN(rb_query);

  char *path = StringValuePtr(rb_path);
  long path_len = RSTRING_LEN(rb_path);

  double score = 0.0;

  if (path_len > 0) {
    pathmatch_t pm;
    pm.query = query;
    pm.query_len = query_len;
    pm.path = path;
    pm.path_len = path_len;
    pm.max_score_per_char = (1.0 / path_len + 1.0 / query_len) / 2.0;
    bzero(pm.qc_pos_map, POS_MAP_SIZE * sizeof(pos_list_t));

    score = compute_score(&pm,
        /* q_beg */ 0, /* p_beg */ 0, /* p_pos_last */ -1);

    pos_list_t *pl = pm.qc_pos_map;
    int i = 0;
    for (; i < POS_MAP_SIZE; pl++, i++) {
      if (pl->initialized) {
        free(pl->pos);
      }
    }
  }

  rb_iv_set(self, "@path", rb_path);
  rb_iv_set(self, "@score", DBL2NUM(score));

  return self;
}

/**
 * Initializes the extension:
 *
 * - Adds a PathMatchC class to the Matcher module with the same interface and
 *   behavior as PathMatch, but with the expensive match logic done in C.
 * - Sets up kPathSep from File::SEPARATOR.
 */
void
Init_pathmatchc()
{
  VALUE mPathMatcher = rb_define_module("PathMatcher");
  VALUE cPathMatchC = rb_define_class_under(
      mPathMatcher, "PathMatchC", rb_cObject);

  rb_define_method(cPathMatchC,
      "initialize", PathMatchC_initialize, /* argc */ 2);

  rb_define_attr(cPathMatchC, "path",  /* read */ 1, /* write */ 0);
  rb_define_attr(cPathMatchC, "score", /* read */ 1, /* write */ 0);

  // Get the path separator character from File::SEPARATOR and store it
  // statically.
  VALUE rb_path_sep = rb_const_get_at(rb_cFile, rb_intern("SEPARATOR"));
  kPathSep = *StringValueCStr(rb_path_sep);
}
