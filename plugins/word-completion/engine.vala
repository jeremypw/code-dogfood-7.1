/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
 *           2011 Lucas Baudin <xapantu@gmail.com>
 *  *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */

public class Euclide.Completion.Parser : GLib.Object {
    // DELIMITERS used for word completion are not necessarily the same Pango word breaks
    // Therefore, we reimplement some iter functions to move between words here below
    public const string DELIMITERS = " .,;:?{}[]()+=&|<>*\\/\r\n\t`\"\'";
    public const int MINIMUM_WORD_LENGTH = 3;
    public const int MAXIMUM_WORD_LENGTH = 50;
    public const int MINIMUM_PREFIX_LENGTH = 1;
    public const int MAX_TOKENS = 100000;
    public static bool is_delimiter (unichar? uc) {
        return uc == null || DELIMITERS.index_of_char (uc) > -1;
    }

    private Scratch.Plugins.PrefixTree? current_tree = null;
    public Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> ();
    }

    public bool select_current_tree (Gtk.TextView view) {
        bool pre_existing = true;
        if (!text_view_words.has_key (view)) {
            var new_treemap = new Scratch.Plugins.PrefixTree ();
            text_view_words.@set (view, new_treemap);
            pre_existing = false;
        }

        lock (current_tree) {
            current_tree = text_view_words.@get (view);
            parsing_cancelled = false;
        }

        return pre_existing && get_initial_parsing_completed ();
    }

    public void set_initial_parsing_completed (bool completed) requires (current_tree != null) {
        lock (current_tree) {
            current_tree.completed = completed;
        }
    }

    public bool get_initial_parsing_completed () requires (current_tree != null) {
        return current_tree.completed;
    }

    // This gets called from a thread
    public void initial_parse_buffer_text (string buffer_text) {
        parsing_cancelled = false;
        clear ();
        if (buffer_text.length > 0) {
            var parsed = parse_text_and_add (buffer_text);
            set_initial_parsing_completed (parsed);
        } else {
            // Assume any buffer text would have been loaded when this is called
            // so definitely no initial parse needed
            set_initial_parsing_completed (true);
        }

        debug ("initial parsing %s", get_initial_parsing_completed () ? "completed" : "INCOMPLETE");
    }

    // Returns true if text was completely parsed
    public bool parse_text_and_add (string text) {
        int index = 0;
        string[] words = text.split_set (DELIMITERS);
        uint n_words = words.length;
        while (!parsing_cancelled && index < n_words) {
            add_word (words[index++]); // only valid words will be added
        }

        return index == n_words;
    }

    public void parse_text_and_remove (string text) {
        if (text.length < MINIMUM_WORD_LENGTH) {
            return;
        }

        int index = 0;
        string[] words = text.split_set (DELIMITERS);
        uint n_words = words.length;
        while (index < n_words) {
            remove_word (words[index++]);
        }

        return;
    }

    public string get_word_immediately_before (Gtk.TextIter iter) {
        int end_pos;
        var text = get_sentence_at_iter (iter, out end_pos);
        var pos = end_pos;
        unichar uc;
        text.get_prev_char (ref pos, out uc);
        if (is_delimiter (uc)) {
            return "";
        }

        pos = (end_pos - MAXIMUM_WORD_LENGTH - 1).clamp (0, end_pos);
        if (pos >= end_pos) {
            critical ("pos after end_pos");
            return "";
        }

        var sliced_text = text.slice (pos, end_pos);
        var words = sliced_text.split_set (DELIMITERS);
        var previous_word = words[words.length - 1]; // Maybe ""
        return previous_word;
    }

    public string get_word_immediately_after (Gtk.TextIter iter) {
        int start_pos;
        var text = get_sentence_at_iter (iter, out start_pos);
        var pos = start_pos;
        unichar uc;
        text.get_next_char (ref pos, out uc);
        if (is_delimiter (uc)) {
            return "";
        }

        // Find end of search range
        pos = (start_pos + MAXIMUM_WORD_LENGTH + 1).clamp (start_pos, text.length);
        if (start_pos >= pos) {
            critical ("start pos after pos");
            return "";
        }

        // Find first word in range
        var words = text.slice (start_pos, pos).split_set (DELIMITERS, 2);
        var next_word = words[0]; // Maybe ""
        return next_word;
    }

    private string get_sentence_at_iter (Gtk.TextIter iter, out int iter_sentence_offset) {
        var start_iter = iter;
        var end_iter = iter;
        start_iter.backward_sentence_start ();
        end_iter.forward_sentence_end ();
        var text = start_iter.get_text (end_iter);
        iter_sentence_offset = iter.get_offset () - start_iter.get_offset ();
        return text;
    }

    public void clear () requires (current_tree != null) {
        cancel_parsing ();
        lock (current_tree) {
            current_tree.clear (); // Sets completed false
            set_initial_parsing_completed (false);

        }

        parsing_cancelled = false;
    }

    public void cancel_parsing () {
        // Do not need to cancel reaping - this continues when prefix_tree is not current
        parsing_cancelled = true;
    }

    private List<string> current_completions;
    private string current_prefix;
    public bool match (string prefix) requires (current_tree != null) {
        lock (current_tree) {
            current_completions = current_tree.get_all_completions (prefix);
            current_prefix = prefix;
        }

        return current_completions != null && current_completions.first ().data != null;
    }

    public List<string> get_current_completions (string prefix) requires (current_tree != null) {
        // Assume always preceded by match and current_completions up to date
        if (current_prefix != prefix) {
            critical ("current prefix does not match");
            match (prefix);
        }

        return (owned)current_completions;
    }

    public void add_word (string word_to_add) requires (current_tree != null) {
        if (is_valid_word (word_to_add)) {
        // warning ("ADD WORD %s", word_to_add);
            lock (current_tree) {
                current_tree.add_word (word_to_add);
            }
        }
    }

    public void remove_word (string word_to_remove) requires (current_tree != null) {
        if (is_valid_word (word_to_remove)) {
    // warning ("REMOVE WORD %s", word_to_remove);
            lock (current_tree) {
                current_tree.remove_word (word_to_remove);
            }
        }
    }

    private bool is_valid_word (string word) {
        if (word.strip ().length < MINIMUM_WORD_LENGTH) {
            return false;
        }

        // Exclude words beginning with digit
        if (word.get_char (0).isdigit ()) {
            return false;
        }

        return true;
    }
}
